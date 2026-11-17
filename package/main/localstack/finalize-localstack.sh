#!/bin/bash
# Post-bump finalize for localstack venv staging (shared alpine/debian leaves).
set -eux -o pipefail

: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

VENV="${TARGET_DIR}/usr/lib/localstack"
PYTHON_MINOR="$("${PYTHON_BIN}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"

"${VENV}/bin/python3" -m pip uninstall -y pip

# Fixes CVE-2025-55163
rm -rf "${VENV}/lib/python${PYTHON_MINOR}/site-packages/amazon_kclpy/jars"

find "${VENV}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} + || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete || true

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

test -e "${VENV}/bin/localstack"
test -e "${VENV}/bin/localstack-supervisor"
ln -sf ../lib/localstack/bin/localstack "${TARGET_DIR}/usr/bin/localstack"
ln -sf ../lib/localstack/bin/localstack-supervisor "${TARGET_DIR}/usr/bin/localstack-supervisor"

mkdir -p /opt/docker/sbom/localstack
chmod -R 0777 /opt/docker/sbom
