#!/usr/bin/env python3
"""Fetch release-pinned bootstrap inputs and record Cabal's library components."""

from __future__ import annotations

import argparse
import hashlib
import http.client
import json
import re
import tarfile
import time
import urllib.request
from pathlib import Path


def verify(data: bytes, checksum: str) -> bytes:
    if not re.fullmatch(r"[0-9a-f]{64}", checksum or ""):
        raise ValueError(f"Invalid SHA256: {checksum}")
    if hashlib.sha256(data).hexdigest() != checksum:
        raise ValueError(f"SHA256 mismatch: expected {checksum}")
    return data


def download(url: str, checksum: str) -> bytes:
    for attempt in range(5):
        try:
            with urllib.request.urlopen(url, timeout=120) as response:
                try:
                    data = response.read()
                except http.client.IncompleteRead as error:
                    # Accept an incomplete HTTP transfer only if all expected
                    # bytes arrived, as proven by the release's checksum.
                    data = error.partial
            return verify(data, checksum)
        except (OSError, http.client.HTTPException, ValueError) as error:
            if attempt == 4:
                raise
            print(f"Retrying {url}: {error}", flush=True)
            time.sleep(2 ** attempt)
    raise AssertionError("Unreachable")


def load_plan(source: Path, plan_name: str) -> dict:
    plan = json.loads((source / "bootstrap" / plan_name).read_text())
    for dep in plan["builtin"] + plan["dependencies"]:
        if not re.fullmatch(r"[A-Za-z0-9-]+", dep["package"]):
            raise ValueError(f"Invalid package: {dep['package']}")
        if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", dep["version"]):
            raise ValueError(f"Invalid version: {dep['version']}")
    for dep in plan["dependencies"]:
        if dep["source"] not in {"hackage", "local"}:
            raise ValueError(f"Unsupported source: {dep['source']}")
        if not dep["component"].startswith(("lib:", "exe:")):
            raise ValueError(f"Unsupported component: {dep['component']}")
    return plan


def fetch_dependencies(source: Path, plan: dict) -> None:
    downloads = {}
    for dep in plan["dependencies"]:
        if dep["source"] == "local":
            continue
        name, version = dep["package"], dep["version"]
        root = f"https://hackage.haskell.org/package/{name}-{version}"
        files = [(f"{name}-{version}.tar.gz", f"{root}/{name}-{version}.tar.gz", dep["src_sha256"])]
        if dep["revision"] is not None:
            revision = dep["revision"]
            if type(revision) is not int or revision < 0:
                raise ValueError(f"Invalid revision: {name}-{version}")
            files.append((f"{name}.cabal", f"{root}/revision/{revision}.cabal", dep["cabal_sha256"]))
        for filename, url, checksum in files:
            if not re.fullmatch(r"[0-9a-f]{64}", checksum or ""):
                raise ValueError(f"Missing SHA256 for {filename}")
            # Upstream keys revised manifests by name, without a version.
            # Reject conflicting entries instead of silently overwriting one.
            previous = downloads.setdefault(filename, (url, checksum))
            if previous != (url, checksum):
                raise ValueError(f"Conflicting bootstrap inputs for {filename}")

    destination = source / "_build/tarballs"
    destination.mkdir(parents=True, exist_ok=True)
    for filename, (url, checksum) in downloads.items():
        (destination / filename).write_bytes(download(url, checksum))
        print(f"Verified {filename}", flush=True)


def fields(text: str) -> dict[str, str]:
    result = {}
    current = None
    for line in text.splitlines():
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


def source_metadata(source: Path, dep: dict) -> dict[str, str]:
    name, version = dep["package"], dep["version"]
    if dep["source"] == "local":
        # Local plan versions can lag the release manifests (e.g. hooks-exe).
        # bootstrap.py builds these sources without enforcing that version.
        info = fields((source / name / f"{name}.cabal").read_text())
    else:
        tarballs = source / "_build/tarballs"
        if dep["revision"] is not None:
            data = verify((tarballs / f"{name}.cabal").read_bytes(), dep["cabal_sha256"])
        else:
            archive = tarballs / f"{name}-{version}.tar.gz"
            verify(archive.read_bytes(), dep["src_sha256"])
            with tarfile.open(archive) as tf:
                data = tf.extractfile(f"{name}-{version}/{name}.cabal").read()
        info = fields(data.decode("utf-8"))
        if info["version"] != version:
            raise ValueError(f"Source version mismatch: {name}-{version}")
    if info["name"] != name:
        raise ValueError(f"Source name mismatch: {name}")
    return info


def git_source(commit: str) -> str:
    # The release tarball named for this version can carry a later component
    # tree. The build checks out the release tag at this commit instead.
    if not re.fullmatch(r"[0-9a-f]{40}", commit or ""):
        raise ValueError(f"Invalid git revision: {commit}")
    return f"git+https://github.com/haskell/cabal.git@{commit}"


def write_sbom(source: Path, plan: dict, compiler_root: Path, compiler_version: str, output: Path, version: str, commit: str) -> None:
    # Where each component was obtained. The hackage archives are the ones this
    # script downloads and checksums above; the local units come out of the
    # pinned cabal commit, and the builtin libraries out of the compiler's.
    # The key cannot collide with a manifest field, which is never underscored.
    cabal_src = git_source(commit)
    ghc_src = f"https://downloads.haskell.org/ghc/{compiler_version}/ghc-{compiler_version}-src.tar.xz"

    components = {}
    for dep in plan["dependencies"]:
        # alex and hsc2hs are bootstrap executables, not shipped libraries.
        if dep["component"].startswith("exe:") and dep["package"] != "cabal-install":
            continue
        info = source_metadata(source, dep)
        name, dep_version = dep["package"], dep["version"]
        info["_download"] = cabal_src if dep["source"] == "local" else (
            f"https://hackage.haskell.org/package/{name}-{dep_version}/{name}-{dep_version}.tar.gz"
        )
        components[(info["name"], info["version"])] = info

    installed = {}
    for path in compiler_root.rglob("package.conf.d/*.conf"):
        info = fields(path.read_text())
        installed[(info["name"], info["version"])] = info
    for dep in plan["builtin"]:
        key = (dep["package"], dep["version"])
        if key not in installed:
            raise ValueError(f"Missing compiler library metadata: {key}")
        info = installed[key].copy()
        info["_download"] = ghc_src
        if info["name"] == "rts":
            # The RTS version is not the GHC release that owns its code.
            info.update(name="ghc", version=compiler_version)
        components[(info["name"], info["version"])] = info

    if ("cabal-install", version) not in components:
        raise ValueError(f"Missing cabal-install {version} source metadata")
    aliases = {"BSD3": "BSD-3-Clause", "BSD2": "BSD-2-Clause"}
    packages = []
    for (name, component_version), info in sorted(components.items()):
        license_id = info["license"]
        if not license_id:
            raise ValueError(f"Missing license: {name}")
        ecosystem = "generic" if name == "ghc" else "hackage"
        packages.append({
            "name": name,
            "SPDXID": f"SPDXRef-{name}-{component_version}",
            "versionInfo": component_version,
            "downloadLocation": info.get("_download", "NOASSERTION"),
            "filesAnalyzed": False,
            "licenseConcluded": "NOASSERTION",
            "licenseDeclared": aliases.get(license_id, license_id),
            "externalRefs": [{"referenceCategory": "PACKAGE-MANAGER", "referenceType": "purl", "referenceLocator": f"pkg:{ecosystem}/{name}@{component_version}"}],
        })
    identity = hashlib.sha256(json.dumps(packages, sort_keys=True).encode()).hexdigest()
    document = {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": f"cabal-install-{version}-components",
        "documentNamespace": f"https://www.haskell.org/cabal/{version}/dhi-components/{identity}",
        "creationInfo": {"creators": ["Organization: Docker, Inc."], "created": "1970-01-01T00:00:00Z"},
        "packages": packages,
        "relationships": [{"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", "relatedSpdxElement": p["SPDXID"]} for p in packages],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, indent=2) + "\n")
    print(f"Recorded {len(packages)} library components in {output}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    fetch = commands.add_parser("fetch")
    sbom = commands.add_parser("sbom")
    for command in (fetch, sbom):
        command.add_argument("--source", type=Path, required=True)
        command.add_argument("--plan", required=True)
    sbom.add_argument("--compiler-root", type=Path, required=True)
    sbom.add_argument("--compiler-version", required=True)
    sbom.add_argument("--output", type=Path, required=True)
    sbom.add_argument("--version", required=True)
    sbom.add_argument("--commit", required=True)
    args = parser.parse_args()
    plan = load_plan(args.source, args.plan)
    if args.command == "fetch":
        fetch_dependencies(args.source, plan)
    else:
        write_sbom(args.source, plan, args.compiler_root, args.compiler_version, args.output, args.version, args.commit)


if __name__ == "__main__":
    main()
