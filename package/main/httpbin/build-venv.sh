#!/bin/bash
# Shared httpbin venv staging for alpine (uv) and debian (venv+pip).
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   HTTPBIN_VERSION  - version stamped into httpbin/VERSION
#   SOURCE_DIR       - checkout with src/, requirements.txt, entrypoint.py
#   TARGET_DIR       - package root (venv lands at ${TARGET_DIR}/usr/lib/httpbin)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${HTTPBIN_VERSION:?HTTPBIN_VERSION is required}"

VENV="${TARGET_DIR}/usr/lib/httpbin"
mkdir -p "${TARGET_DIR}/usr/lib"

if command -v uv >/dev/null 2>&1; then
  uv venv --python /usr/bin/python3.13 "${VENV}"
  uv pip install --python "${VENV}/bin/python" --no-deps \
    -r "${SOURCE_DIR}/requirements.txt"
else
  /usr/bin/python3.13 -m venv --without-pip "${VENV}"
  /usr/bin/python3.13 -m pip --python "${VENV}/bin/python" install \
    --no-cache-dir --no-deps -r "${SOURCE_DIR}/requirements.txt"
fi

printf '%s' "${HTTPBIN_VERSION}" > "${SOURCE_DIR}/src/httpbin/VERSION"
purelib="$("${VENV}/bin/python" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
cp -a "${SOURCE_DIR}/src/httpbin" "${purelib}/httpbin"
install -m0755 "${SOURCE_DIR}/entrypoint.py" "${VENV}/bin/httpbin"
find "${VENV}" -depth -type d -name __pycache__ -exec rm -rf {} +

# pip/uv may bake the build-time path into shebangs; normalize to the final path.
for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

mkdir -p /opt/docker/sbom/httpbin
chmod -R 0777 /opt/docker/sbom
