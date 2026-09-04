#!/bin/bash
# Shared mlflow venv staging for the debian leaf.
# Exported by the definition pipeline (melange vars are not expanded here):
#   SOURCE_DIR  - work dir containing mlflow/ (verified upstream checkout)
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.12)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

SRC="${SOURCE_DIR}/mlflow"
VENV="${TARGET_DIR}/usr/lib/mlflow"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

export YARN_CACHE_FOLDER="${YARN_CACHE_FOLDER:-/root/.yarn}"
cd "${SRC}/mlflow/server/js"
yarn install
yarn build

cd "${SRC}"
"${PYTHON_BIN}" -m venv --without-pip "${VENV}"
"${PYTHON_BIN}" -m pip --python "${VENV}/bin/python3" install --no-cache-dir --upgrade pip setuptools wheel

export CPPFLAGS="${CPPFLAGS:-} $("${PYTHON_BIN}-config" --includes)"
export CFLAGS="${CFLAGS:-} $("${PYTHON_BIN}-config" --includes)"
export LDFLAGS="${LDFLAGS:-} $("${PYTHON_BIN}-config" --ldflags)"

"${VENV}/bin/python3" -m pip install .
# Pin to a version for reproducibility/security. OK to bump in the future
"${VENV}/bin/python3" -m pip install --no-build-isolation --no-binary=psycopg2 --no-cache-dir "psycopg2==2.9.12"

# Remediate CVEs by upgrading packages
"${VENV}/bin/python3" -m pip install --upgrade "urllib3==2.7.0"
"${VENV}/bin/python3" -m pip install --upgrade "cryptography==50.0.0"
"${VENV}/bin/python3" -m pip install --upgrade "pillow==12.3.0"
"${VENV}/bin/python3" -m pip install --upgrade "starlette==1.3.1"
"${VENV}/bin/python3" -m pip install --upgrade "gitpython==3.1.59"

find "${VENV}" \( -type d -a \( -name test -o -name tests -o -name __pycache__ \) \) -prune -exec rm -rf {} + || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

test -e "${VENV}/bin/mlflow"
ln -sf ../lib/mlflow/bin/mlflow "${TARGET_DIR}/usr/bin/mlflow"

mkdir -p /opt/docker/sbom/mlflow
chmod -R 0777 /opt/docker/sbom
