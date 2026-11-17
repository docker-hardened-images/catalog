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

# moment (jupyterhub static asset): CVE-2026-17495 — tarball staged in definition contents.files
MOMENT_TARBALL="${SOURCE_DIR}/moment-2.31.0.tgz"
MOMENT_COMPONENT="${VENV}/share/jupyterhub/static/components/moment"
if [ -f "${MOMENT_TARBALL}" ] && [ -d "${MOMENT_COMPONENT}" ]; then
  rm -rf "${MOMENT_COMPONENT}"
  mkdir -p "${MOMENT_COMPONENT}"
  "${PYTHON_BIN}" - "${MOMENT_TARBALL}" "${MOMENT_COMPONENT}" <<'PY'
import shutil
import sys
import tarfile
import tempfile
from pathlib import Path

archive, dest = Path(sys.argv[1]), Path(sys.argv[2])
with tempfile.TemporaryDirectory() as tmp:
    with tarfile.open(archive, "r:gz") as tf:
        tf.extractall(tmp)
    shutil.copytree(Path(tmp) / "package", dest, dirs_exist_ok=True)
PY
fi

# pip vendors urllib3 2.7.0; the runtime venv does not need pip after staging.
"${PYTHON_BIN}" -m pip --python "${VENV_PY}" uninstall -y pip setuptools wheel

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
