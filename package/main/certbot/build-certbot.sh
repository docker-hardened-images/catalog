#!/bin/bash
# Debian certbot venv staging — mirrors image/certbot pip install (source acme +
# certbot, cryptography built against system OpenSSL).
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing certbot-src/ checkout (acme/, certbot/)
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.14)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

VENV="${TARGET_DIR}/usr/lib/certbot/.venv"
CERTBOT_SRC="${SOURCE_DIR}/certbot-src"

mkdir -p "${TARGET_DIR}/usr/lib/certbot" "${TARGET_DIR}/usr/bin"

"${PYTHON_BIN}" -m venv --without-pip "${VENV}"
"${PYTHON_BIN}" -m pip --python "${VENV}/bin/python3" install \
  --upgrade pip setuptools wheel

cd "${CERTBOT_SRC}"
"${VENV}/bin/python3" -m pip install --no-cache-dir \
  --no-binary=cryptography \
  ./acme \
  ./certbot

# CVE-2026-8643 (26.1.1 -> 26.1.2); CVE-2026-13346 (26.1.2 -> 26.2)
"${VENV}/bin/python3" -m pip install --no-cache-dir --upgrade pip==26.2

find "${VENV}" \( -type d \( -name test -o -name tests -o -name __pycache__ \) -prune -exec rm -rf {} + \)
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

test -e "${VENV}/bin/certbot"
ln -sf ../lib/certbot/.venv/bin/certbot "${TARGET_DIR}/usr/bin/certbot"

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

test -x "${TARGET_DIR}/usr/bin/certbot"
