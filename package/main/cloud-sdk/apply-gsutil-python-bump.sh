#!/bin/bash
# Sync gsutil vendored httplib2 and setup.py pins from patch/gsutil-requirements.txt
# after python/bump@v1 rewrites that file.
set -euo pipefail

GSUTIL_DIR="${1:?gsutil platform directory}"
REQ_FILE="${2:?requirements file with httplib2 pin}"

VERSION="$(grep -E '^httplib2==' "$REQ_FILE" | head -1 | sed -E 's/^httplib2==([^ \\]+).*/\1/')"
[ -n "$VERSION" ]
grep -qE '^[[:space:]]*--hash=sha256:' "$REQ_FILE"

SETUP_PY="$GSUTIL_DIR/setup.py"
VENDOR_SETUP="$GSUTIL_DIR/third_party/httplib2/setup.py"
VENDOR_PY="$GSUTIL_DIR/third_party/httplib2/python3/httplib2"
STAGE="$(mktemp -d)"

cleanup() {
  rm -rf "$STAGE"
}
trap cleanup EXIT

UV_BIN="${UV_BIN:-/opt/docker/dhi/bin/uv}"
if [ ! -x "$UV_BIN" ] && command -v uv >/dev/null 2>&1; then
  UV_BIN="$(command -v uv)"
fi
[ -x "$UV_BIN" ]

"$UV_BIN" pip install --quiet --no-deps --require-hashes \
  --python "${PYTHON_BIN:-/usr/bin/python3.13}" \
  --target "$STAGE" -r "$REQ_FILE"

rm -rf "$VENDOR_PY"
install -d "$(dirname "$VENDOR_PY")"
cp -a "$STAGE/httplib2" "$VENDOR_PY"

sed -i "s/httplib2==[0-9][^'\"]*/httplib2==${VERSION}/g" "$SETUP_PY"
sed -i "s/^VERSION = \"[0-9].*\"/VERSION = \"${VERSION}\"/" "$VENDOR_SETUP"

grep -q "httplib2==${VERSION}" "$SETUP_PY"
grep -q "VERSION = \"${VERSION}\"" "$VENDOR_SETUP"
