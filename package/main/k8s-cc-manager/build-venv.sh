#!/bin/bash
# Stage k8s-cc-manager venv, application scripts, and vendored gpu-admin-tools
# under ${TARGET_DIR}/usr/lib/k8s-cc-manager (FHS). Expects:
#   SOURCE_DIR         - parent of k8s-cc-manager/ and gpu-admin-tools/ checkouts
#   TARGET_DIR         - package root
#   PYTHON_BIN         - interpreter (e.g. /usr/bin/python3.13)
#   REQUIREMENTS_LOCK  - hashed transitive lock (deb or musl leaf)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${REQUIREMENTS_LOCK:?REQUIREMENTS_LOCK is required}"

APP="${SOURCE_DIR}/k8s-cc-manager"
TOOLS="${SOURCE_DIR}/gpu-admin-tools"
PKG_ROOT="${TARGET_DIR}/usr/lib/k8s-cc-manager"
VENV="${PKG_ROOT}/.venv"

mkdir -p "${PKG_ROOT}"

"${PYTHON_BIN}" -m venv --without-pip "${VENV}"
"${PYTHON_BIN}" -m pip --python "${VENV}/bin/python" install \
  --no-cache-dir --no-deps --require-hashes -r "${REQUIREMENTS_LOCK}"
"${PYTHON_BIN}" -m pip --python "${VENV}/bin/python" check

"${PYTHON_BIN}" -m pip --python "${VENV}/bin/python" uninstall --yes pip setuptools wheel 2>/dev/null || \
  "${PYTHON_BIN}" -m pip --python "${VENV}/bin/python" uninstall --yes pip 2>/dev/null || true

cp "${APP}/main.py" "${APP}/gpu_operator_eviction.py" "${PKG_ROOT}/"

cp -a "${TOOLS}" "${PKG_ROOT}/gpu-admin-tools"
rm -rf "${PKG_ROOT}/gpu-admin-tools/.git"

find "${VENV}" \( -type d \( -name test -o -name tests -o -name __pycache__ \) -prune -exec rm -rf {} + \) || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

mkdir -p /opt/docker/sbom/k8s-cc-manager
# Directory write for the SBOM scanner only. Recursive 0777 was copied
# onto the packaged application SPDX file by the later cp -a.
chmod 0777 /opt/docker/sbom /opt/docker/sbom/k8s-cc-manager
