#!/bin/bash
# Shared jupyterhub-k8s-singleuser-sample venv staging for debian.
# Expects (exported by the definition pipeline):
#   SOURCE_DIR  - work dir containing zero-to-jupyterhub-k8s/ checkout
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.14)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

SAMPLE_DIR="${SOURCE_DIR}/zero-to-jupyterhub-k8s/images/singleuser-sample"
VENV="${TARGET_DIR}/usr/lib/jupyterhub-k8s-singleuser-sample"

mkdir -p "${TARGET_DIR}/usr/lib"

cd "${SAMPLE_DIR}"
VENV_PY="${VENV}/bin/$(basename "${PYTHON_BIN}")"
"${PYTHON_BIN}" -m venv --without-pip "${VENV}"
"${PYTHON_BIN}" -m pip --python "${VENV_PY}" install --upgrade pip setuptools wheel
"${PYTHON_BIN}" -m pip --python "${VENV_PY}" install --no-cache-dir \
  -r requirements.txt

"${PYTHON_BIN}" -m pip --python "${VENV_PY}" uninstall -y pip setuptools wheel

find "${VENV}" \( -type d \( -name test -o -name tests -o -name __pycache__ \) -prune -exec rm -rf {} + \)
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

# nbclassic vendors moment 2.29.4 (CVE-2026-17495); replace it with the 2.31.0 release tarball.
MOMENT_TARBALL="${SOURCE_DIR}/moment-2.31.0.tgz"
test -f "${MOMENT_TARBALL}"

moment_dirs=0
while IFS= read -r -d '' MOMENT_COMPONENT; do
  moment_dirs=$((moment_dirs + 1))
  MOMENT_TMP="$(mktemp -d)"
  "${PYTHON_BIN}" -c "import sys, tarfile; tarfile.open(sys.argv[1], 'r:gz').extractall(sys.argv[2], filter='data')" \
    "${MOMENT_TARBALL}" "${MOMENT_TMP}"
  rm -rf "${MOMENT_COMPONENT}"
  mkdir -p "${MOMENT_COMPONENT}"
  cp -a "${MOMENT_TMP}/package/." "${MOMENT_COMPONENT}/"
  rm -rf "${MOMENT_TMP}"
  grep -q '"version": "2.31.0"' "${MOMENT_COMPONENT}/package.json"
done < <(find "${VENV}" -path '*/components/moment' -type d -print0)
test "${moment_dirs}" -gt 0

# nbclassic vendors underscore 1.13.7 (CVE-2026-27601); replace it with the 1.13.8 release tarball.
UNDERSCORE_TARBALL="${SOURCE_DIR}/underscore-1.13.8.tgz"
test -f "${UNDERSCORE_TARBALL}"

underscore_dirs=0
while IFS= read -r -d '' UNDERSCORE_COMPONENT; do
  underscore_dirs=$((underscore_dirs + 1))
  UNDERSCORE_TMP="$(mktemp -d)"
  "${PYTHON_BIN}" -c "import sys, tarfile; tarfile.open(sys.argv[1], 'r:gz').extractall(sys.argv[2], filter='data')" \
    "${UNDERSCORE_TARBALL}" "${UNDERSCORE_TMP}"
  rm -rf "${UNDERSCORE_COMPONENT}"
  mkdir -p "${UNDERSCORE_COMPONENT}"
  cp -a "${UNDERSCORE_TMP}/package/." "${UNDERSCORE_COMPONENT}/"
  rm -rf "${UNDERSCORE_TMP}"
  grep -q '"version": "1.13.8"' "${UNDERSCORE_COMPONENT}/package.json"
done < <(find "${VENV}" -path '*/components/underscore' -type d -print0)
test "${underscore_dirs}" -gt 0

test -x "${VENV}/bin/jupyter"

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done
