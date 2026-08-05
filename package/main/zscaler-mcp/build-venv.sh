#!/bin/bash
# Shared zscaler-mcp venv staging for alpine and debian.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing src/ (upstream checkout)
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

SRC="${SOURCE_DIR}/src"
VENV="${TARGET_DIR}/opt/zscaler-mcp"

mkdir -p "${TARGET_DIR}/opt" "${TARGET_DIR}/usr/bin"

cd "${SRC}"
rm -f .python-version
export UV_PYTHON="${PYTHON_BIN}"
export UV_PYTHON_DOWNLOADS=never
export UV_PROJECT_ENVIRONMENT="${VENV}"
export UV_COMPILE_BYTECODE="${UV_COMPILE_BYTECODE:-1}"

uv lock --upgrade
uv sync --locked --no-install-project --no-dev --no-editable
uv sync --locked --no-dev --no-editable --extra gcp

# Drop caches/tests from the shipped venv. Prune the directory branch so -exec
# applies to it (a trailing -o file branch would otherwise capture -exec alone),
# then remove any stray bytecode separately.
find "${VENV}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} + || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

# Relative symlink so apk/dpkg --root installs (the buildpkg tests) resolve it
# under the chroot; an absolute /opt/... target breaks -e checks there. Only
# zscaler-mcp (the MCP server entrypoint) is exposed on PATH; zscaler-mcp-tokens
# is a secondary token-comparison utility that remains reachable at
# /opt/zscaler-mcp/bin/zscaler-mcp-tokens.
test -e "${VENV}/bin/zscaler-mcp"
ln -sf ../../opt/zscaler-mcp/bin/zscaler-mcp "${TARGET_DIR}/usr/bin/zscaler-mcp"

# uv may bake the build-time staging path into generated script shebangs;
# normalize them to the final runtime path.
for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

mkdir -p /opt/docker/sbom/zscaler-mcp
chmod -R 0777 /opt/docker/sbom
