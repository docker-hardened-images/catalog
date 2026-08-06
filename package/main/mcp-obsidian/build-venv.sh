#!/bin/bash
# Shared mcp-obsidian venv staging for debian.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing mcp-obsidian/ (upstream checkout)
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.14)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

SRC="${SOURCE_DIR}/mcp-obsidian"
VENV="${TARGET_DIR}/usr/lib/mcp-obsidian"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

cd "${SRC}"
rm -f .python-version
export UV_PYTHON="${PYTHON_BIN}"
export UV_PYTHON_DOWNLOADS=never
export UV_PROJECT_ENVIRONMENT="${VENV}"
export UV_COMPILE_BYTECODE="${UV_COMPILE_BYTECODE:-1}"

uv lock --upgrade
uv sync --locked --no-install-project --no-dev --no-editable
uv sync --locked --no-dev --no-editable

find "${VENV}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} + || true

# Relative link so apk --root installs (buildpkg TestAPK) resolve under the
# chroot; absolute /usr/lib/... targets break -e path checks there.
test -e "${TARGET_DIR}/usr/lib/mcp-obsidian/bin/mcp-obsidian"
ln -sf ../lib/mcp-obsidian/bin/mcp-obsidian "${TARGET_DIR}/usr/bin/mcp-obsidian"

# pip/uv may bake the build-time path into shebangs; normalize to the final path.
for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

mkdir -p /opt/docker/sbom/mcp-obsidian
chmod -R 0777 /opt/docker/sbom
