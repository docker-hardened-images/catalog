#!/bin/bash
# Check the staged payload against its notices and SBOM documents: every
# Python distribution, bundled npm package and linked Rust crate that ships
# must appear in an SBOM, and must have a license file somewhere in the
# package.
# ${...} is not expanded here, so the definition must export:
#   SOURCE_DIR  - work dir with the crate inventory
#   TARGET_DIR  - package root, with the SBOM documents already staged
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"

export SOURCE_DIR TARGET_DIR
VENV="${TARGET_DIR}/usr/lib/kubeflow-volumes-web-app/venv"

"${VENV}/bin/python" - <<'EOF'
import glob
import importlib.metadata
import json
import os
import re
import sys

target = os.environ["TARGET_DIR"]
source = os.environ["SOURCE_DIR"]
sbom_root = os.path.join(target, "opt/docker/sbom")
licenses = os.path.join(target, "usr/share/licenses/kubeflow-volumes-web-app")
static = os.path.join(target, "usr/lib/kubeflow-volumes-web-app/src/apps/default/static")
errors = []


def norm(name):
    return re.sub(r"[-_.]+", "-", name).lower()


def sbom_docs(prefix):
    paths = glob.glob(os.path.join(sbom_root, prefix, "**", "*.json"), recursive=True)
    paths += glob.glob(os.path.join(sbom_root, prefix, "**", ".*.json"), recursive=True)
    if not paths:
        errors.append(f"no SBOM document under {prefix}")
    docs = []
    for path in sorted(set(paths)):
        with open(path, encoding="utf-8") as f:
            docs.append(json.load(f))
    return docs


def purls(docs, kind):
    found = set()
    for doc in docs:
        for pkg in doc.get("packages", []):
            for ref in pkg.get("externalRefs", []):
                loc = ref.get("referenceLocator", "")
                if loc.startswith(f"pkg:{kind}/"):
                    found.add(loc.split("?", 1)[0].split("#", 1)[0])
    return found


# Python: every installed distribution is in the Python SBOM and carries a
# license file, except the two whose license is staged elsewhere.
covered_elsewhere = {
    "kubeflow": os.path.join(licenses, "LICENSE"),
}
dists = list(importlib.metadata.distributions())
if not dists:
    errors.append("venv has no distributions")
for dist in dists:
    if norm(dist.metadata["Name"]) == "flask-cors":
        covered_elsewhere["flask-cors"] = os.path.join(licenses, f"python/flask-cors-{dist.version}/LICENSE")
python_purls = {
    (norm(p.split("/", 1)[1].rsplit("@", 1)[0]), p.rsplit("@", 1)[1])
    for p in purls(sbom_docs("kubeflow-volumes-web-app-python"), "pypi")
}
for dist in dists:
    name = norm(dist.metadata["Name"])
    if (name, dist.version) not in python_purls:
        errors.append(f"pypi {name} {dist.version} missing from the Python SBOM")
    notices = [
        f for f in (dist.files or [])
        if ".dist-info" in str(f)
        and re.match(r"(LICEN[CS]E|COPYING|NOTICE)", os.path.basename(str(f)), re.I)
    ]
    if name in covered_elsewhere:
        if notices:
            errors.append(f"{name} now ships its own license file; drop the staged copy")
        if not os.path.isfile(covered_elsewhere[name]):
            errors.append(f"{name} license not staged at {covered_elsewhere[name]}")
    elif not notices:
        errors.append(f"pypi {name} {dist.version} ships no license file")

# Frontend: every package the Angular build names in 3rdpartylicenses.txt,
# and the two copied in as assets, is in the npm SBOM. kubeflow is the
# in-repo common library, covered by the source SPDX document.
npm_docs = sbom_docs("kubeflow-volumes-web-app-frontend")
npm_names = {pkg.get("name") for doc in npm_docs for pkg in doc.get("packages", [])}
heading = re.compile(r"^(@[a-z0-9][a-z0-9._~-]*/)?[a-z0-9][a-z0-9._~-]*$")
with open(os.path.join(static, "3rdpartylicenses.txt"), encoding="utf-8") as f:
    lines = f.read().split("\n")
bundled = {
    line for i, line in enumerate(lines)
    if heading.match(line) and (i == 0 or lines[i - 1] == "")
}
if "@angular/core" not in bundled:
    errors.append("3rdpartylicenses.txt parsed without @angular/core")
for name in sorted((bundled - {"kubeflow"}) | {"monaco-editor", "material-icons"}):
    if name not in npm_names:
        errors.append(f"npm {name} missing from the frontend SBOM")
for notice in ("LICENSE", "ThirdPartyNotices.txt"):
    if not os.path.isfile(os.path.join(static, "assets/monaco-editor", notice)):
        errors.append(f"assets/monaco-editor/{notice} missing")

# Rust: every crate linked into cryptography's extension is in the cargo
# SBOM and has its notices staged.
cargo_purls = purls(sbom_docs("kubeflow-volumes-web-app-cargo"), "cargo")
with open(os.path.join(source, "cryptography-cargo-inventory.txt"), encoding="utf-8") as f:
    linked = [l.split()[:2] for l in f if re.match(r"^[a-z0-9_-]+ \S+ linked ", l)]
if not linked:
    errors.append("inventory lists no linked crates")
for name, version in linked:
    if f"pkg:cargo/{name}@{version}" not in cargo_purls:
        errors.append(f"cargo {name} {version} missing from the cargo SBOM")
    if not os.listdir(os.path.join(licenses, "cargo", f"{name}-{version}")):
        errors.append(f"cargo {name} {version} has no staged notice")

# Source identity of the upstream checkout.
if "pkg:github/kubeflow/notebooks" not in json.dumps(sbom_docs("kubeflow-volumes-web-app")):
    errors.append("source SPDX document lacks pkg:github/kubeflow/notebooks")

for e in errors:
    print(e, file=sys.stderr)
sys.exit(1 if errors else 0)
EOF
