#!/bin/bash
# Build the two upstream-shaped auto-instrumentation trees for one leaf.
#
# Each leaf installs the locked distributions into TWO trees under
# ${TARGET_DIR}/usr/lib/opentelemetry-autoinstrumentation-python/:
#   ${NATIVE_LIBC}   installed natively by this leaf's interpreter
#   <other libc>     the same locked set, cross-installed from prebuilt wheels
#                    for the other libc (pip --platform, --only-binary)
# Upstream ships both trees in one image (/autoinstrumentation and
# /autoinstrumentation-musl) and the operator picks one per pod.
#
# ${...} is not expanded inside a mounted script, so the leaf exports:
#   SOURCE_DIR     work dir: requirements.txt (operator, checksum-pinned),
#                  requirements-lock.txt, patch/python-bumps.json
#   TARGET_DIR     package root
#   VERSION        upstream opentelemetry-distro version, e.g. 0.66b2
#   PYTHON_MINOR   interpreter minor this leaf runs, e.g. 3.15
#   UPSTREAM_PYTHON_MINOR  minor upstream's Dockerfile builds with
#   PY_ARCH        x86_64 or aarch64
#   NATIVE_LIBC    glibc or musl
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${VERSION:?VERSION is required}"
: "${PYTHON_MINOR:?PYTHON_MINOR is required}"
: "${UPSTREAM_PYTHON_MINOR:?UPSTREAM_PYTHON_MINOR is required}"
: "${PY_ARCH:?PY_ARCH is required}"
: "${NATIVE_LIBC:?NATIVE_LIBC is required}"

case "${NATIVE_LIBC}" in
  glibc) CROSS_LIBC=musl ;;
  musl) CROSS_LIBC=glibc ;;
  *) echo "NATIVE_LIBC must be glibc or musl" >&2; exit 1 ;;
esac

LOCK="${SOURCE_DIR}/requirements-lock.txt"
REQS="${SOURCE_DIR}/requirements.txt"
BUMPS="${SOURCE_DIR}/python-bumps.json"
ROOT="${TARGET_DIR}/usr/lib/opentelemetry-autoinstrumentation-python"
NATIVE_TREE="${ROOT}/${NATIVE_LIBC}"
CROSS_TREE="${ROOT}/${CROSS_LIBC}"
PY="/usr/bin/python${PYTHON_MINOR}"

test -f "${LOCK}"
test -f "${REQS}"
test -f "${BUMPS}"

# Interpreter guard. A different minor changes the cp3NN ABI of every native
# module, so a minor change is a reviewed bump, never a silent rebuild.
test -n "${UPSTREAM_PYTHON_MINOR}"
if [ "${UPSTREAM_PYTHON_MINOR}" != "${PYTHON_MINOR}" ]; then
  echo "upstream builds with python ${UPSTREAM_PYTHON_MINOR}, this leaf runs ${PYTHON_MINOR}" >&2
  exit 1
fi

# pip writes #!${sys.executable} into bin/. Run pip with the interpreter the
# python-3.N runtime dependency ships, so the shebangs name a path the installed
# package can rely on. Upstream's /usr/local/bin/python3 is a base-image path,
# not something this package ships.
test -x "${PY}"

# pip, from the wheel the interpreter package ships. Debian keeps it under
# /usr/share/python-wheels, Alpine under the stdlib's ensurepip directory.
PIP_WHEEL=""
for candidate in /usr/share/python-wheels/pip-*-py3-none-any.whl \
  "$(${PY} -c 'import ensurepip,os;print(os.path.join(os.path.dirname(ensurepip.__file__),"_bundled"))')"/pip-*-py3-none-any.whl; do
  if [ -f "${candidate}" ]; then
    PIP_WHEEL="${candidate}"
    break
  fi
done
test -n "${PIP_WHEEL}"
pip() { PYTHONPATH="${PIP_WHEEL}" "${PY}" -m pip "$@"; }
pyrun() { PYTHONPATH="${PIP_WHEEL}" "${PY}" "$@"; }
pip --version

# Lock guard. Every direct requirement of the operator's requirements.txt must
# be met by the lock, and the lock must pin the distro version this leaf
# claims. Only packages in python-bumps.json may differ from upstream's
# specifiers, and only at the bumped version. pip's vendored packaging does the
# PEP 440 comparison, so no extra download is needed.
pyrun - "${LOCK}" "${REQS}" "${BUMPS}" "${VERSION}" <<'PYEOF'
import json
import re
import sys

from pip._vendor.packaging.requirements import Requirement
from pip._vendor.packaging.utils import canonicalize_name

lock_path, reqs_path, bumps_path, version = sys.argv[1:5]

pins = {}
for line in open(lock_path):
    m = re.match(r"^([A-Za-z0-9._-]+)==([^\s\\]+)", line)
    if m:
        pins[canonicalize_name(m.group(1))] = m.group(2)

direct = {}
for raw in open(reqs_path):
    line = raw.split("#", 1)[0].strip()
    if not line or line.startswith("-"):
        continue
    req = Requirement(line)
    direct[canonicalize_name(req.name)] = req

bumped = {canonicalize_name(b["package"]): b["version"] for b in json.load(open(bumps_path))}

errors = []
if pins.get("opentelemetry-distro") != version:
    errors.append(f"lock pins opentelemetry-distro {pins.get('opentelemetry-distro')}, want {version}")
for name, req in sorted(direct.items()):
    if name not in pins:
        errors.append(f"direct requirement {name} is missing from the lock")
    elif name in bumped:
        if pins[name] != bumped[name]:
            errors.append(f"{name} is bumped to {bumped[name]} but the lock pins {pins[name]}")
    elif not req.specifier.contains(pins[name], prereleases=True):
        errors.append(f"lock pins {name}=={pins[name]}, outside upstream's {req.specifier}")
stale = sorted(set(bumped) - set(direct))
for name in stale:
    errors.append(f"python-bumps.json names {name}, which upstream does not require")
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"lock guard ok: {len(direct)} direct requirements, {len(pins)} pins, {len(bumped)} bumps")
PYEOF

# SOURCE_DATE_EPOCH makes compileall write checked-hash .pyc (flags 3). The
# hash is of the source, so the bytecode is the same for both libcs, and it
# stays valid after the operator's mtime-resetting cp -r. Upstream's timestamp
# .pyc go stale there.
export SOURCE_DATE_EPOCH=0
export PIP_DISABLE_PIP_VERSION_CHECK=1
export PIP_NO_INPUT=1

PYVER_NODOT="${PYTHON_MINOR//./}"
COMMON=(--no-cache-dir --no-deps --require-hashes --only-binary=:all:)

# Native tree: the interpreter's own libc, no platform override.
mkdir -p "${NATIVE_TREE}"
pip install "${COMMON[@]}" --target "${NATIVE_TREE}" -r "${LOCK}"

# Cross tree: the other libc's wheels for the same locked versions. Pure-Python
# wheels (py3-none-any) match through the "any" platform. The implementation,
# python-version and abi flags keep pip on cp${PYVER_NODOT} / abi3 / none wheels.
CROSS_ARGS=(--implementation cp --python-version "${PYTHON_MINOR}"
  --abi "cp${PYVER_NODOT}" --abi abi3 --abi none)
if [ "${CROSS_LIBC}" = musl ]; then
  CROSS_PLATFORMS=(--platform "musllinux_1_2_${PY_ARCH}" --platform "musllinux_1_1_${PY_ARCH}"
    --platform "musllinux_1_0_${PY_ARCH}" --platform any)
else
  CROSS_PLATFORMS=(--platform "manylinux_2_28_${PY_ARCH}" --platform "manylinux_2_17_${PY_ARCH}"
    --platform "manylinux2014_${PY_ARCH}" --platform "manylinux_2_5_${PY_ARCH}"
    --platform "manylinux1_${PY_ARCH}" --platform any)
fi
mkdir -p "${CROSS_TREE}"
pip install "${COMMON[@]}" "${CROSS_ARGS[@]}" "${CROSS_PLATFORMS[@]}" \
  --target "${CROSS_TREE}" -r "${LOCK}"

for tree in "${NATIVE_TREE}" "${CROSS_TREE}"; do
  # Every .pyc must be checked-hash (flags == 3). A timestamp .pyc here means
  # SOURCE_DATE_EPOCH did not reach compileall and the bytecode would go stale.
  sample=$(find "${tree}" -name '*.cpython-'"${PYVER_NODOT}"'.pyc' -print -quit)
  test -n "${sample}"
  flags=$(od -An -tu4 -j4 -N4 "${sample}" | tr -d ' ')
  if [ "${flags}" != "3" ]; then
    echo "${sample} has pyc flags ${flags}, want 3 (checked-hash)" >&2
    exit 1
  fi
done

# Parity cleanup, per tree. REQUESTED marks only the operator's direct
# requirements, as in upstream's image (60 markers, the same names). A --no-deps
# install from the full lock marks all 79. direct_url.json names this build's
# paths and is dropped.
pyrun - "${REQS}" "${NATIVE_TREE}" "${CROSS_TREE}" "${LOCK}" "${TARGET_DIR}" "${SOURCE_DIR}" <<'PYEOF'
import os
import re
import sys
from pathlib import Path

from pip._vendor.packaging.utils import canonicalize_name

reqs_path, native, cross, lock_path, target_dir, source_dir = sys.argv[1:7]

direct = set()
for raw in open(reqs_path):
    line = raw.split("#", 1)[0].strip()
    if not line or line.startswith("-"):
        continue
    direct.add(canonicalize_name(re.match(r"[A-Za-z0-9._-]+", line).group(0)))

pins = {}
for line in open(lock_path):
    m = re.match(r"^([A-Za-z0-9._-]+)==([^\s\\]+)", line)
    if m:
        pins[canonicalize_name(m.group(1))] = m.group(2)

# Match the build's own staging and source paths exactly. A bare "/out" or
# "/src" also matches ordinary upstream text (urllib3 ssltransport, psutil).
forbidden = [target_dir + "/usr/", lock_path, reqs_path, source_dir + "/python-bumps.json"]
errors = []
for tree in (native, cross):
    tree_p = Path(tree)
    seen = {}
    for dist in sorted(tree_p.glob("*.dist-info")):
        name, version = dist.name[: -len(".dist-info")].rsplit("-", 1)
        seen[canonicalize_name(name)] = version
        req = dist / "REQUESTED"
        if req.exists() and canonicalize_name(name) not in direct:
            req.unlink()
        direct_url = dist / "direct_url.json"
        if direct_url.exists():
            direct_url.unlink()
    requested = sum(1 for d in tree_p.glob("*.dist-info") if (d / "REQUESTED").exists())
    if requested != len(direct):
        errors.append(f"{tree}: {requested} REQUESTED markers, want {len(direct)}")
    if seen != pins:
        missing = sorted(set(pins) - set(seen))
        extra = sorted(set(seen) - set(pins))
        drift = sorted(k for k in set(seen) & set(pins) if seen[k] != pins[k])
        errors.append(f"{tree}: inventory differs from the lock (missing {missing}, extra {extra}, drift {drift})")
    for path in tree_p.rglob("*"):
        if path.is_symlink() or not path.is_file():
            continue
        if path.suffix in (".pyc", ".so") or path.stat().st_size > 4_000_000:
            continue
        data = path.read_bytes()
        for leak in forbidden:
            if leak.encode() in data:
                errors.append(f"build path {leak} present in {path}")
                break
if errors:
    print("\n".join(errors), file=sys.stderr)
    sys.exit(1)
print(f"parity ok: {len(pins)} distributions per tree, {len(direct)} REQUESTED markers")
PYEOF

# Shebang and leak check: scripts must point at the installed interpreter, and
# no file may name this build's staging root or the work dir.
for tree in "${NATIVE_TREE}" "${CROSS_TREE}"; do
  if [ -d "${tree}/bin" ]; then
    for f in "${tree}/bin"/*; do
      [ -f "$f" ] || continue
      head -1 "$f" | grep -qxF "#!/usr/bin/python${PYTHON_MINOR}" \
        || { echo "unexpected shebang in $f: $(head -1 "$f")" >&2; exit 1; }
    done
  fi
done

# Only the staging prefix and this build's own source files. Bare "/out" or
# "/src" also match upstream text (urllib3 ssltransport, psutil, packaging).
leaks=$(grep -rlF -e "${TARGET_DIR}/usr/" -e "${SOURCE_DIR}/requirements" -e "${SOURCE_DIR}/python-bumps" \
  "${ROOT}" --exclude='*.pyc' --exclude='*.so' || true)
if [ -n "${leaks}" ]; then
  echo "build-time path still present in:" >&2
  echo "${leaks}" >&2
  exit 1
fi
