#!/bin/bash
# Shared patroni install staging for the debian package leaf.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing patroni/
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.13)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

SRC="${SOURCE_DIR}/patroni"
VENV="${TARGET_DIR}/usr/lib/patroni"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

cd "${SRC}"

"${PYTHON_BIN}" -m venv "${VENV}"
# shellcheck disable=SC1091
source "${VENV}/bin/activate"

# Installs patroni with the common DCS backends (consul/zookeeper/raft
# users layer a derived image). psycopg comes via its [c] source extra
# rather than patroni's [psycopg3] extra, which hard-pins
# psycopg[binary] and its bundled libpq/OpenSSL; building psycopg-c
# from source links the system libpq, keeping -fips variants on the
# FIPS OpenSSL for the patroni-to-postgres hop.
pip install --no-cache-dir ".[etcd3,kubernetes]" "psycopg[c]>=3.0"
# Pin the urllib3 Patroni imports. Do not install msgpack: the published
# package's only copy is pip/_vendor/msgpack, and uninstalling pip removes
# it. A standalone wheel has no consumer in this payload.
pip install --no-cache-dir "urllib3==2.8.0"

# Runtime image does not need pip; removing it drops pip's vendored msgpack,
# urllib3, and setuptools rows Scout would otherwise index separately from
# site-packages.
pip uninstall -y pip setuptools wheel
sp="$(echo "${VENV}"/lib/python*/site-packages)"
rm -rf "${sp}"/pip "${sp}"/pip-*.dist-info \
  "${sp}"/setuptools "${sp}"/setuptools-*.dist-info "${sp}"/pkg_resources \
  "${sp}"/_distutils_hack "${sp}"/distutils-precedence.pth \
  "${sp}"/wheel "${sp}"/wheel-*.dist-info

deactivate

find "${VENV}" \( -type d \( -name test -o -name tests -o -name __pycache__ \) -prune -exec rm -rf {} + \) || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete || true

for f in "${VENV}/bin/patroni" "${VENV}/bin/patronictl"; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

test -e "${VENV}/bin/patroni"
test -e "${VENV}/bin/patronictl"
ln -sf ../lib/patroni/bin/patroni "${TARGET_DIR}/usr/bin/patroni"
ln -sf ../lib/patroni/bin/patronictl "${TARGET_DIR}/usr/bin/patronictl"
