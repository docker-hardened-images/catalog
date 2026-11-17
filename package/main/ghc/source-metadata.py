#!/usr/bin/env python3
"""Fetch the source release's Hadrian inputs and describe installed components."""

from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import re
import time
import urllib.request
from pathlib import Path


def download(url: str, checksum: str) -> bytes:
    for attempt in range(5):
        try:
            with urllib.request.urlopen(url, timeout=120) as response:
                try:
                    data = response.read()
                except http.client.IncompleteRead as error:
                    # Some mirrors omit the final chunk. Only accept the bytes
                    # when the source release's checksum proves they are whole.
                    data = error.partial
            if hashlib.sha256(data).hexdigest() != checksum:
                raise ValueError(f"SHA256 mismatch: {url}")
            return data
        except (OSError, http.client.HTTPException, ValueError) as error:
            if attempt == 4:
                raise
            print(f"Retrying {url}: {error}", flush=True)
            time.sleep(2 ** attempt)
    raise AssertionError("Unreachable")


def fetch_dependencies(source: Path, bootstrap_version: str) -> None:
    if not re.fullmatch(r"[0-9]+(?:[.][0-9]+)+", bootstrap_version):
        raise ValueError(f"Invalid bootstrap GHC version: {bootstrap_version}")
    plan_name = f"plan-bootstrap-{bootstrap_version.replace('.', '_')}.json"
    plan = json.loads((source / "hadrian/bootstrap" / plan_name).read_text())
    destination = source / "hadrian/_build/tarballs"
    destination.mkdir(parents=True, exist_ok=True)
    for dependency in plan["dependencies"]:
        if dependency["source"] != "hackage":
            continue
        name, version = dependency["package"], dependency["version"]
        if not re.fullmatch(r"[A-Za-z0-9-]+", name) or not re.fullmatch(r"[0-9.]+", version):
            raise ValueError(f"Invalid dependency: {name}-{version}")
        root = f"https://hackage.haskell.org/package/{name}-{version}"
        downloads = [(f"{name}-{version}.tar.gz", f"{root}/{name}-{version}.tar.gz", dependency["src_sha256"])]
        if dependency.get("revision") is not None:
            downloads.append((f"{name}.cabal", f"{root}/revision/{int(dependency['revision'])}.cabal", dependency["cabal_sha256"]))
        for filename, url, checksum in downloads:
            if not re.fullmatch(r"[0-9a-f]{64}", checksum):
                raise ValueError(f"Missing SHA256 for {filename}")
            data = download(url, checksum)
            (destination / filename).write_bytes(data)
            print(f"Verified {filename}", flush=True)


def fields(path: Path) -> dict[str, str]:
    result = {}
    current = None
    for line in path.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith("--"):
            continue
        match = re.match(r"^([A-Za-z-]+):[ \t]*(.*)$", line)
        if match:
            current = match[1].lower()
            result[current] = match[2].strip()
        elif line[0].isspace() and current is not None:
            result[current] = (result[current] + " " + line.strip()).strip()
        else:
            current = None
    return result


def verify_debian_toolchain(gcc_version: str, defaults_version: str, triplet: str) -> None:
    # The frontend compares pinned names against escaped download URLs, so
    # names containing '+' cannot use its '=version' check. Enforce those
    # versions against the installed control records before any compilation.
    expected = {
        "g++": defaults_version,
        f"g++-{triplet}": defaults_version,
        "g++-14": gcc_version,
        f"g++-14-{triplet}": gcc_version,
        "libstdc++-14-dev": gcc_version,
    }
    for name, version in expected.items():
        actual = fields(Path("/var/lib/dpkg/status.d") / name)["version"]
        if actual != version:
            raise ValueError(f"Build tool {name}: expected {version}, installed {actual}")
        print(f"Verified build tool {name}={version}", flush=True)


def write_sbom(source: Path, package_root: Path, output: Path, version: str) -> None:
    installed = {}
    for path in package_root.rglob("package.conf.d/*.conf"):
        info = fields(path)
        installed[info["name"]] = info["version"]
    if not installed:
        raise ValueError(f"No installed package database under {package_root}")

    candidates = list((source / "libraries").rglob("*.cabal"))
    candidates += list((source / "utils/haddock").rglob("*.cabal"))
    haddock = package_root / "bin/haddock"
    # Haddock's libraries can be linked into the program without being
    # registered in the shipped compiler's package database.
    haddock_components = {"haddock", "haddock-api", "haddock-library"} if (
        haddock.exists() or haddock.is_symlink()
    ) else set()
    wanted = installed.keys() | haddock_components
    components = {}
    aliases = {"BSD3": "BSD-3-Clause", "BSD2": "BSD-2-Clause"}
    for path in sorted(candidates, key=lambda p: (len(p.parts), str(p))):
        # Cabal also contains intentionally malformed test fixtures. Only
        # inspect manifests for installed libraries and the Haddock program.
        if path.stem not in wanted:
            continue
        if path.stem in components:
            continue
        info = fields(path)
        name = info.get("name", "")
        if name in components or name not in wanted:
            continue
        if name in installed and info.get("version") != installed[name]:
            continue
        component_version = info["version"]
        license_id = aliases.get(info["license"], info["license"])
        components[name] = (component_version, license_id, f"pkg:hackage/{name}@{component_version}")

    missing = wanted - components.keys() - {"rts", "ghc", "ghc-toolchain", "system-cxx-std-lib"}
    if missing:
        raise ValueError(f"No source metadata for installed libraries: {sorted(missing)}")
    archives = list((source / "libffi-tarballs").glob("libffi-*.tar.gz"))
    if len(archives) != 1:
        raise ValueError("Expected exactly one bundled libffi archive")
    ffi_version = archives[0].name.removeprefix("libffi-").removesuffix(".tar.gz")
    components["libffi"] = (ffi_version, "MIT", f"pkg:generic/libffi@{ffi_version}")
    components["ghc"] = (version, "BSD-3-Clause", f"pkg:generic/ghc@{version}")

    # Every component here comes out of the GHC source release: the boot
    # libraries, haddock and the bundled libffi are all in its tree. The purl
    # names the component for advisory matching; this says where it was
    # obtained, which is not Hackage even where a component is published there.
    source_url = f"https://downloads.haskell.org/ghc/{version}/ghc-{version}-src.tar.xz"
    packages = []
    for name, (component_version, license_id, purl) in sorted(components.items()):
        packages.append({
            "name": name,
            "SPDXID": f"SPDXRef-{name}",
            "versionInfo": component_version,
            "downloadLocation": source_url,
            "filesAnalyzed": False,
            "licenseConcluded": "NOASSERTION",
            "licenseDeclared": license_id,
            "externalRefs": [{"referenceCategory": "PACKAGE-MANAGER", "referenceType": "purl", "referenceLocator": purl}],
        })
    document = {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": f"ghc-{version}-components",
        "documentNamespace": f"https://www.haskell.org/ghc/{version}/dhi-components",
        "creationInfo": {"creators": ["Organization: Docker, Inc."], "created": "1970-01-01T00:00:00Z"},
        "packages": packages,
        "relationships": [{"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", "relatedSpdxElement": p["SPDXID"]} for p in packages],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, indent=2) + "\n")
    print(f"Recorded {len(packages)} shipped components in {output}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    fetch = commands.add_parser("fetch")
    fetch.add_argument("--source", type=Path, required=True)
    fetch.add_argument("--bootstrap-version", required=True)
    verify = commands.add_parser("verify-debian-toolchain")
    verify.add_argument("--gcc-version", required=True)
    verify.add_argument("--defaults-version", required=True)
    verify.add_argument("--triplet", required=True)
    sbom = commands.add_parser("sbom")
    sbom.add_argument("--source", type=Path, required=True)
    sbom.add_argument("--package-root", type=Path, required=True)
    sbom.add_argument("--output", type=Path, required=True)
    sbom.add_argument("--version", required=True)
    args = parser.parse_args()
    if args.command == "fetch":
        fetch_dependencies(args.source, args.bootstrap_version)
    elif args.command == "verify-debian-toolchain":
        verify_debian_toolchain(args.gcc_version, args.defaults_version, args.triplet)
    else:
        write_sbom(args.source, args.package_root, args.output, args.version)


if __name__ == "__main__":
    main()
