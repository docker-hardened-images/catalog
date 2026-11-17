#!/usr/bin/env python3
"""Describe the components cabal resolved into the stack executable."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import tarfile
from pathlib import Path

ALIASES = {"BSD3": "BSD-3-Clause", "BSD2": "BSD-2-Clause"}


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


def cabal_package_roots() -> list[Path]:
    """Every directory cabal may have cached downloaded manifests under.

    cabal 3.12 moved from ~/.cabal to the XDG directories and honours CABAL_DIR
    over both, so the layout depends on the cabal that ran, not on this script.
    """
    home = Path(os.environ.get("HOME", "/root"))
    candidates = [
        Path(os.environ["CABAL_DIR"]) / "packages" if os.environ.get("CABAL_DIR") else None,
        Path(os.environ["XDG_CACHE_HOME"]) / "cabal/packages" if os.environ.get("XDG_CACHE_HOME") else None,
        home / ".cache/cabal/packages",
        home / ".cabal/packages",
    ]
    return [c for c in candidates if c is not None and c.is_dir()]


def hackage_license(roots: list[Path], name: str, version: str) -> str | None:
    for root in roots:
        for directory in root.glob(f"*/{name}/{version}"):
            manifest = directory / f"{name}.cabal"
            try:
                if manifest.is_file():
                    return fields(manifest.read_text(errors="replace")).get("license") or None
                archive = directory / f"{name}-{version}.tar.gz"
                if archive.is_file():
                    with tarfile.open(archive) as tf:
                        member = tf.extractfile(f"{name}-{version}/{name}.cabal")
                        if member is not None:
                            return fields(member.read().decode("utf-8", "replace")).get("license") or None
            except (OSError, tarfile.TarError, KeyError):
                continue
    return None


def compiler_licenses(compiler_root: Path) -> dict[tuple[str, str], str]:
    found: dict[tuple[str, str], str] = {}
    for path in compiler_root.rglob("package.conf.d/*.conf"):
        try:
            info = fields(path.read_text(errors="replace"))
        except OSError:
            continue
        if info.get("name") and info.get("version") and info.get("license"):
            found[(info["name"], info["version"])] = info["license"]
    return found


def local_licenses(source: Path) -> dict[str, str]:
    found: dict[str, str] = {}
    for path in source.glob("*.cabal"):
        try:
            info = fields(path.read_text(errors="replace"))
        except OSError:
            continue
        if info.get("name") and info.get("license"):
            found[info["name"]] = info["license"]
    return found


def repo_tarball(unit: dict, name: str, version: str) -> str:
    """Where cabal fetched a repo-tar unit from.

    The plan records the repository root, not the archive, so the path follows
    the repository layout. A plan without a usable root asserts nothing rather
    than naming a location this build did not use.
    """
    uri = ((unit.get("pkg-src") or {}).get("repo") or {}).get("uri") or ""
    if not uri.startswith(("http://", "https://")):
        return "NOASSERTION"
    return f"{uri.rstrip('/')}/package/{name}-{version}/{name}-{version}.tar.gz"


def components(plan: dict, compiler_version: str, compiler_root: Path, source: Path) -> dict[tuple[str, str], tuple[str, str, str]]:
    """Collect every package the plan builds or reuses, with its source, licence and origin."""
    from_compiler = compiler_licenses(compiler_root)
    from_source = local_licenses(source)
    roots = cabal_package_roots()
    # The compiler's own libraries and the stack tree are not fetched by cabal,
    # so their origin is the release each was built from.
    ghc_src = f"https://downloads.haskell.org/ghc/{compiler_version}/ghc-{compiler_version}-src.tar.xz"
    found: dict[tuple[str, str], tuple[str, str, str]] = {}
    for unit in plan["install-plan"]:
        name, version = unit["pkg-name"], unit["pkg-version"]
        if not re.fullmatch(r"[A-Za-z0-9-]+", name):
            raise ValueError(f"Invalid package: {name}")
        if not re.fullmatch(r"[0-9]+(?:\.[0-9]+)*", version):
            raise ValueError(f"Invalid version: {name}-{version}")
        # Pre-existing units are Haskell packages supplied by the compiler, so
        # retain their Hackage identity even though this build reuses the
        # installed copy. Local units come from the Stack source tree. An
        # unknown source fails rather than being recorded as something it is not.
        if unit.get("type") == "pre-existing":
            source_kind = "hackage"
            download = ghc_src
            license_id = from_compiler.get((name, version))
            # The RTS version is not the compiler release that owns its code.
            if name == "rts":
                name, version = "ghc", compiler_version
                source_kind = "generic"
            elif name == "ghc" and version == compiler_version:
                source_kind = "generic"
        else:
            kind = (unit.get("pkg-src") or {}).get("type")
            if kind == "local":
                source_kind = "generic"
                license_id = from_source.get(name)
                download = f"git+https://github.com/commercialhaskell/stack.git@v{version}"
            elif kind == "repo-tar":
                source_kind = "hackage"
                license_id = hackage_license(roots, name, version)
                download = repo_tarball(unit, name, version)
            else:
                raise ValueError(f"Unsupported source for {name}-{version}: {kind}")
        found[(name, version)] = (source_kind, ALIASES.get(license_id, license_id) if license_id else "NOASSERTION", download)
    if not found:
        raise ValueError("Plan resolved no components")
    return found


def write_sbom(plan: dict, version: str, compiler_version: str, compiler_root: Path, source: Path, output: Path) -> None:
    resolved = components(plan, compiler_version, compiler_root, source)
    if ("stack", version) not in resolved:
        raise ValueError(f"Plan does not build stack {version}")

    packages = []
    for (name, component_version), (ecosystem, license_id, download) in sorted(resolved.items()):
        packages.append({
            "name": name,
            "SPDXID": f"SPDXRef-{name}-{component_version}",
            "versionInfo": component_version,
            "downloadLocation": download,
            "filesAnalyzed": False,
            "licenseConcluded": "NOASSERTION",
            "licenseDeclared": license_id,
            "externalRefs": [{
                "referenceCategory": "PACKAGE-MANAGER",
                "referenceType": "purl",
                "referenceLocator": f"pkg:{ecosystem}/{name}@{component_version}",
            }],
        })

    identity = hashlib.sha256(json.dumps(packages, sort_keys=True).encode()).hexdigest()
    document = {
        "spdxVersion": "SPDX-2.3",
        "dataLicense": "CC0-1.0",
        "SPDXID": "SPDXRef-DOCUMENT",
        "name": f"stack-{version}-components",
        "documentNamespace": f"https://haskellstack.org/{version}/dhi-components/{identity}",
        "creationInfo": {"creators": ["Organization: Docker, Inc."], "created": "1970-01-01T00:00:00Z"},
        "packages": packages,
        "relationships": [
            {"spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", "relatedSpdxElement": p["SPDXID"]}
            for p in packages
        ],
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(document, indent=2) + "\n")
    declared = sum(1 for p in packages if p["licenseDeclared"] != "NOASSERTION")
    print(f"Recorded {len(packages)} components in {output}")
    print(f"Resolved {declared} of {len(packages)} component licences")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--compiler-version", required=True)
    parser.add_argument("--compiler-root", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    write_sbom(json.loads(args.plan.read_text()), args.version, args.compiler_version,
               args.compiler_root, args.source, args.output)


if __name__ == "__main__":
    main()
