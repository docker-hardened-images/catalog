#!/bin/bash
# Debian kubeflow-pipelines-metadata-writer venv staging.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR           - work dir containing kubeflow-pipelines/ checkout
#   TARGET_DIR           - package root
#   PYTHON_BIN           - interpreter path (e.g. /usr/bin/python3.11)
#   METADATA_WRITER_DIR  - path to backend/metadata_writer in the checkout
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${METADATA_WRITER_DIR:?METADATA_WRITER_DIR is required}"

APP="${TARGET_DIR}/usr/lib/kubeflow-pipelines-metadata-writer"

mkdir -p "$(dirname "${APP}")"
rm -rf "${APP}"

cd "${METADATA_WRITER_DIR}"

cp -a src "${APP}"

"${PYTHON_BIN}" -m venv --without-pip "${APP}/.venv"
"${PYTHON_BIN}" -m pip --python "${APP}/.venv/bin/python3" install \
  --no-cache-dir -r requirements.txt

for f in "${APP}/.venv/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

find "${APP}" \
  \( -type d -a \( -name test -o -name tests -o -name __pycache__ \) \) \
  -o \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) \
  -exec rm -rf '{}' + || true

test -f "${APP}/metadata_writer.py"
