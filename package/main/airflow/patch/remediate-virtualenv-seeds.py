#!/usr/bin/python3
"""Remove obsolete virtualenv seeds and remediate the retained pip seed."""

from __future__ import annotations

import base64
import csv
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import sys
import tempfile
import zipfile


OLD_PIP_VERSION = "26.0.1"
PIP_VERSION = "26.2.2"
OLD_SETUPTOOLS_VERSION = "82.0.1"
SETUPTOOLS_VERSION = "84.2.1"
MSGPACK_VERSION = "1.2.4"
URLLIB3_VERSION = "2.8.0"


def fail(message: str) -> None:
    raise SystemExit(message)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def record_hash(data: bytes) -> str:
    digest = hashlib.sha256(data).digest()
    encoded = base64.urlsafe_b64encode(digest).rstrip(b"=").decode()
    return f"sha256={encoded}"


def distribution_dir(site: Path, name: str, version: str) -> Path:
    matches = list(site.glob(f"{name}-{version}.dist-info"))
    if len(matches) != 1:
        fail(f"expected one {name} {version} dist-info, found {len(matches)}")
    metadata = matches[0] / "METADATA"
    installed = next(
        (
            line.removeprefix("Version: ")
            for line in metadata.read_text(encoding="utf-8").splitlines()
            if line.startswith("Version: ")
        ),
        "",
    )
    if installed != version:
        fail(f"{name} METADATA version is {installed}, expected {version}")
    return matches[0]


def replace_once(text: str, pattern: str, replacement: str, label: str) -> str:
    result, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        fail(f"expected one {label} replacement, found {count}")
    return result


def bump_component(document: dict, name: str, old_version: str, new_version: str) -> None:
    old_purl = f"pkg:pypi/{name}@{old_version}"
    new_purl = f"pkg:pypi/{name}@{new_version}"
    matches = [component for component in document.get("components", []) if component.get("name") == name]
    if len(matches) != 1:
        fail(f"expected one {name} component in pip vendor SBOM, found {len(matches)}")
    component = matches[0]
    if component.get("version") != old_version or component.get("purl") != old_purl:
        fail(f"unexpected {name} component in pip vendor SBOM")
    component["version"] = new_version
    component["purl"] = new_purl
    component["bom-ref"] = new_purl

    for dependency in document.get("dependencies", []):
        if dependency.get("ref") == old_purl:
            dependency["ref"] = new_purl
        dependency["dependsOn"] = [
            new_purl if item == old_purl else item for item in dependency.get("dependsOn", [])
        ]

    if old_purl in json.dumps(document):
        fail(f"stale {old_purl} remains in pip vendor SBOM")


def copy_vendor_tree(site: Path, work: Path, name: str, dist_info: Path) -> None:
    destination = work / "pip" / "_vendor" / name
    shutil.rmtree(destination)
    shutil.copytree(
        site / name,
        destination,
        ignore=shutil.ignore_patterns("__pycache__", "*.pyc", "*.so"),
    )
    licenses = dist_info / "licenses"
    license_files = sorted(path for path in licenses.rglob("*") if path.is_file())
    if not license_files:
        fail(f"no license file found for {name}")
    preferred = next(
        (path for path in license_files if path.name in {"COPYING", "LICENSE", "LICENSE.txt"}),
        license_files[0],
    )
    license_name = "COPYING" if name == "msgpack" else "LICENSE.txt"
    shutil.copyfile(preferred, destination / license_name)


def write_wheel_record(work: Path) -> None:
    record = work / f"pip-{PIP_VERSION}.dist-info" / "RECORD"
    rows: list[list[str]] = []
    for path in sorted(item for item in work.rglob("*") if item.is_file() and item != record):
        data = path.read_bytes()
        rows.append([path.relative_to(work).as_posix(), record_hash(data), str(len(data))])
    rows.append([record.relative_to(work).as_posix(), "", ""])
    with record.open("w", encoding="utf-8", newline="") as stream:
        csv.writer(stream, lineterminator="\n").writerows(rows)


def repack_wheel(work: Path, wheel: Path) -> str:
    replacement = wheel.with_suffix(".replacement.whl")
    replacement.unlink(missing_ok=True)
    with zipfile.ZipFile(
        replacement,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for path in sorted(item for item in work.rglob("*") if item.is_file()):
            relative = path.relative_to(work).as_posix()
            info = zipfile.ZipInfo(relative, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            mode = stat.S_IMODE(path.stat().st_mode)
            info.external_attr = (mode & 0xFFFF) << 16
            archive.writestr(info, path.read_bytes(), compresslevel=9)
    os.replace(replacement, wheel)
    return sha256_bytes(wheel.read_bytes())


def update_bundle_config(config: Path, new_pip_hash: str) -> None:
    text = config.read_text(encoding="utf-8")
    text = replace_once(
        text,
        r'^    "3\.9": \{\n(?:        .*\n)+?    \},\n',
        "",
        "Python 3.9 bundle block",
    )
    text = replace_once(
        text,
        rf'^    "pip-{re.escape(OLD_PIP_VERSION)}-py3-none-any\.whl": "[0-9a-f]{{64}}",\n',
        "",
        "obsolete pip checksum",
    )
    text = replace_once(
        text,
        rf'^    "setuptools-{re.escape(OLD_SETUPTOOLS_VERSION)}-py3-none-any\.whl": "[0-9a-f]{{64}}",\n',
        "",
        "obsolete setuptools checksum",
    )
    text = replace_once(
        text,
        rf'(^    "pip-{re.escape(PIP_VERSION)}-py3-none-any\.whl": ")[0-9a-f]{{64}}(",\n)',
        rf"\g<1>{new_pip_hash}\g<2>",
        "retained pip checksum",
    )
    config.write_text(text, encoding="utf-8")
    if OLD_PIP_VERSION in text or OLD_SETUPTOOLS_VERSION in text or '"3.9"' in text:
        fail("obsolete virtualenv seed references remain in bundle config")


def file_components(wheel: Path, pip_ref: str) -> list[dict]:
    result = []
    with zipfile.ZipFile(wheel) as archive:
        for info in sorted(archive.infolist(), key=lambda item: item.filename):
            if info.is_dir():
                continue
            data = archive.read(info)
            result.append(
                {
                    "type": "file",
                    "bom-ref": f"{pip_ref}#{info.filename}",
                    "name": info.filename,
                    "hashes": [{"alg": "SHA-256", "content": sha256_bytes(data)}],
                    "properties": [{"name": "size", "value": str(len(data))}],
                }
            )
    return result


def update_virtualenv_sbom(sbom_path: Path, wheel: Path, new_pip_hash: str) -> None:
    document = json.loads(sbom_path.read_text(encoding="utf-8"))
    old_refs = {
        f"pkg:pypi/pip@{OLD_PIP_VERSION}",
        f"pkg:pypi/setuptools@{OLD_SETUPTOOLS_VERSION}",
    }
    components = document.get("components", [])
    document["components"] = [
        component for component in components if component.get("bom-ref") not in old_refs
    ]
    if len(document["components"]) != len(components) - 2:
        fail("obsolete seed components were not uniquely removed from virtualenv SBOM")

    pip_ref = f"pkg:pypi/pip@{PIP_VERSION}"
    pip_matches = [
        component for component in document["components"] if component.get("bom-ref") == pip_ref
    ]
    if len(pip_matches) != 1:
        fail(f"expected one retained pip component, found {len(pip_matches)}")
    pip_component = pip_matches[0]
    hashes = pip_component.get("hashes", [])
    sha_hashes = [item for item in hashes if item.get("alg") == "SHA-256"]
    if len(sha_hashes) != 1:
        fail("expected one SHA-256 hash on retained pip component")
    old_pip_hash = sha_hashes[0].get("content", "")
    sha_hashes[0]["content"] = new_pip_hash
    for identity in pip_component.get("evidence", {}).get("identity", []):
        if identity.get("field") != "hash":
            continue
        for method in identity.get("methods", []):
            if method.get("value") == old_pip_hash:
                method["value"] = new_pip_hash

    libraries = [
        child for child in pip_component.get("components", []) if child.get("type") != "file"
    ]
    replacements = {
        f"pkg:pypi/msgpack@1.1.2": f"pkg:pypi/msgpack@{MSGPACK_VERSION}",
        f"pkg:pypi/urllib3@2.7.0": f"pkg:pypi/urllib3@{URLLIB3_VERSION}",
    }
    for library in libraries:
        name = library.get("name")
        if name == "msgpack":
            library["version"] = MSGPACK_VERSION
            library["purl"] = replacements["pkg:pypi/msgpack@1.1.2"]
        elif name == "urllib3":
            library["version"] = URLLIB3_VERSION
            library["purl"] = replacements["pkg:pypi/urllib3@2.7.0"]
        reference = library.get("bom-ref", "")
        for old, new in replacements.items():
            reference = reference.replace(old, new)
        library["bom-ref"] = reference
    pip_component["components"] = file_components(wheel, pip_ref) + libraries

    dependencies = []
    for dependency in document.get("dependencies", []):
        reference = dependency.get("ref", "")
        if any(reference == old or reference.startswith(f"{old}#") for old in old_refs):
            continue
        for old, new in replacements.items():
            reference = reference.replace(old, new)
        dependency["ref"] = reference
        dependency["dependsOn"] = [
            next((item.replace(old, new) for old, new in replacements.items() if old in item), item)
            for item in dependency.get("dependsOn", [])
            if not any(item == old or item.startswith(f"{old}#") for old in old_refs)
        ]
        dependencies.append(dependency)
    document["dependencies"] = dependencies

    rendered = json.dumps(document, indent=2)
    for stale in (
        f"pip@{OLD_PIP_VERSION}",
        f"setuptools@{OLD_SETUPTOOLS_VERSION}",
        "msgpack@1.1.2",
        "urllib3@2.7.0",
    ):
        if stale in rendered:
            fail(f"stale {stale} remains in virtualenv SBOM")
    sbom_path.write_text(f"{rendered}\n", encoding="utf-8")


def update_virtualenv_record(site: Path, dist_info: Path) -> None:
    record = dist_info / "RECORD"
    with record.open(encoding="utf-8", newline="") as stream:
        paths = [Path(row[0]) for row in csv.reader(stream) if row]
    rows: list[list[str]] = []
    for relative in paths:
        path = site / relative
        if path == record or not path.is_file():
            continue
        data = path.read_bytes()
        rows.append([relative.as_posix(), record_hash(data), str(len(data))])
    rows.append([record.relative_to(site).as_posix(), "", ""])
    with record.open("w", encoding="utf-8", newline="") as stream:
        csv.writer(stream, lineterminator="\n").writerows(rows)


def main() -> None:
    if len(sys.argv) != 2:
        fail("usage: remediate-virtualenv-seeds.py <site-packages>")
    site = Path(sys.argv[1])
    if not site.is_dir():
        fail(f"site-packages not found: {site}")

    dist_infos = list(site.glob("virtualenv-*.dist-info"))
    if len(dist_infos) != 1:
        fail(f"expected one virtualenv dist-info, found {len(dist_infos)}")
    virtualenv_dist_info = dist_infos[0]
    embed = site / "virtualenv" / "seed" / "wheels" / "embed"
    config = embed / "__init__.py"
    sbom = virtualenv_dist_info / "sboms" / "virtualenv.cdx.json"
    old_pip = embed / f"pip-{OLD_PIP_VERSION}-py3-none-any.whl"
    pip_wheel = embed / f"pip-{PIP_VERSION}-py3-none-any.whl"
    old_setuptools = embed / f"setuptools-{OLD_SETUPTOOLS_VERSION}-py3-none-any.whl"
    setuptools_wheel = embed / f"setuptools-{SETUPTOOLS_VERSION}-py3-none-any.whl"
    for path in (config, sbom, old_pip, pip_wheel, old_setuptools, setuptools_wheel):
        if not path.is_file():
            fail(f"expected virtualenv seed file not found: {path}")

    msgpack_dist_info = distribution_dir(site, "msgpack", MSGPACK_VERSION)
    urllib3_dist_info = distribution_dir(site, "urllib3", URLLIB3_VERSION)

    with tempfile.TemporaryDirectory() as temporary:
        work = Path(temporary)
        with zipfile.ZipFile(pip_wheel) as archive:
            archive.extractall(work)
        copy_vendor_tree(site, work, "msgpack", msgpack_dist_info)
        copy_vendor_tree(site, work, "urllib3", urllib3_dist_info)

        vendor_txt = work / "pip" / "_vendor" / "vendor.txt"
        text = vendor_txt.read_text(encoding="utf-8")
        text = replace_once(
            text,
            r"^msgpack==1\.1\.2$",
            f"msgpack=={MSGPACK_VERSION}",
            "msgpack vendor pin",
        )
        text = replace_once(
            text,
            r"^([ \t]*)urllib3==2\.7\.0$",
            rf"\g<1>urllib3=={URLLIB3_VERSION}",
            "urllib3 vendor pin",
        )
        vendor_txt.write_text(text, encoding="utf-8")

        vendor_sbom = work / "pip" / "_vendor" / "bom.cdx.json"
        vendor_document = json.loads(vendor_sbom.read_text(encoding="utf-8"))
        bump_component(vendor_document, "msgpack", "1.1.2", MSGPACK_VERSION)
        bump_component(vendor_document, "urllib3", "2.7.0", URLLIB3_VERSION)
        vendor_sbom.write_text(f"{json.dumps(vendor_document, indent=2)}\n", encoding="utf-8")

        write_wheel_record(work)
        new_pip_hash = repack_wheel(work, pip_wheel)

    old_pip.unlink()
    old_setuptools.unlink()
    update_bundle_config(config, new_pip_hash)
    update_virtualenv_sbom(sbom, pip_wheel, new_pip_hash)
    update_virtualenv_record(site, virtualenv_dist_info)

    print(
        f"retained pip {PIP_VERSION} and setuptools {SETUPTOOLS_VERSION}; "
        f"vendored msgpack {MSGPACK_VERSION} and urllib3 {URLLIB3_VERSION}"
    )


if __name__ == "__main__":
    main()
