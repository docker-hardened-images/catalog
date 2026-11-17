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
"${VENV}/bin/python3" -m pip install --upgrade "urllib3==2.8.0"
"${VENV}/bin/python3" -m pip install --upgrade "cryptography==50.0.0"
# pillow 13.0.0 clears Scout on pkg:pypi/pillow (see package/main/netbox/files/overrides.txt).
"${VENV}/bin/python3" -m pip install --upgrade "pillow==13.0.0" # CVE-2026-96636 CVE-2026-96637 CVE-2026-96638 CVE-2026-96639 CVE-2026-96640 CVE-2026-96641 CVE-2026-96642 CVE-2026-96643 CVE-2026-96644 CVE-2026-96778 CVE-2026-112390 CVE-2026-112391 CVE-2026-112392 CVE-2026-112393 CVE-2026-112394 CVE-2026-112396 CVE-2026-112398 CVE-2026-112399 CVE-2026-112401 CVE-2026-112402 CVE-2026-112405 CVE-2026-112406 CVE-2026-112891 CVE-2026-112892 CVE-2026-112893 CVE-2026-112894 CVE-2026-112898 CVE-2026-112900 CVE-2026-112901 CVE-2026-112902 CVE-2026-114501 GHSA-78G4-XQWV-Q3G8
"${VENV}/bin/python3" -m pip install --upgrade "certifi==2026.10.23" # CVE-2026-53995
"${VENV}/bin/python3" -m pip install --upgrade "starlette==1.3.1"
"${VENV}/bin/python3" -m pip install --upgrade "gitpython==3.2.1"  # CVE-2026-114145; GHSA-59cr-6r3x-644w; CVE-2026-87817, CVE-2026-87818, CVE-2026-87819

"${VENV}/bin/python3" -m pip uninstall -y pip setuptools wheel
sp="$(echo "${VENV}"/lib/python*/site-packages)"
rm -rf "${sp}"/pip "${sp}"/pip-*.dist-info \
  "${sp}"/setuptools "${sp}"/setuptools-*.dist-info "${sp}"/pkg_resources \
  "${sp}"/_distutils_hack "${sp}"/distutils-precedence.pth \
  "${sp}"/wheel "${sp}"/wheel-*.dist-info

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
