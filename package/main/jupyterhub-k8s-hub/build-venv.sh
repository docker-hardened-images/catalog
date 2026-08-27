#!/bin/bash
# Shared jupyterhub-k8s-hub venv staging for alpine and debian.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing zero-to-jupyterhub-k8s/ checkout
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.14)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

HUB_DIR="${SOURCE_DIR}/zero-to-jupyterhub-k8s/images/hub"
VENV="${TARGET_DIR}/usr/lib/jupyterhub-k8s-hub"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

cd "${HUB_DIR}"
VENV_PY="${VENV}/bin/$(basename "${PYTHON_BIN}")"
export PG_CONFIG="${PG_CONFIG:-/usr/bin/pg_config}"
"${PYTHON_BIN}" -m venv --without-pip "${VENV}"
"${PYTHON_BIN}" -m pip --python "${VENV_PY}" install --upgrade pip setuptools wheel
"${PYTHON_BIN}" -m pip --python "${VENV_PY}" install --no-cache-dir \
  --no-binary pycurl \
  -r requirements.txt

# aiohttp: CVE-2026-22815 CVE-2026-34513 CVE-2026-34514 CVE-2026-34515 CVE-2026-34516
#   CVE-2026-34517 CVE-2026-34518 CVE-2026-34519 CVE-2026-34520 CVE-2026-34525
# cryptography: CVE-2026-39892
# urllib3: CVE-2026-44431 CVE-2026-44432
# idna: CVE-2026-45409
# pyjwt: CVE-2026-48522 CVE-2026-48524 CVE-2026-48525 CVE-2026-48526
# tornado: CVE-2026-49854
# pyasn1: CVE-2026-59884 CVE-2026-59885 CVE-2026-59886
"${PYTHON_BIN}" -m pip --python "${VENV_PY}" install --no-cache-dir --upgrade \
  'aiohttp>=3.13.4' \
  'cryptography>=46.0.7' \
  'urllib3>=2.7.0' \
  'idna>=3.15' \
  'pyjwt>=2.13.0' \
  'tornado>=6.5.6' \
  'pyasn1>=0.6.4'

find "${VENV}" \( -type d \( -name test -o -name tests -o -name __pycache__ \) -prune -exec rm -rf {} + \)
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

test -e "${TARGET_DIR}/usr/lib/jupyterhub-k8s-hub/bin/jupyterhub"
ln -sf ../lib/jupyterhub-k8s-hub/bin/jupyterhub "${TARGET_DIR}/usr/bin/jupyterhub"

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done
