#!/bin/bash
# Shared git-mcp venv staging for alpine and debian.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing servers/ (upstream checkout)
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.14)
#   VERSION     - CalVer tag aligned with pyproject.toml
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${VERSION:?VERSION is required}"

SRC="${SOURCE_DIR}/servers/src/git"
VENV="${TARGET_DIR}/usr/lib/git-mcp"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

# starlette is a transitive dep from mcp/uvicorn — CVE-2026-54283
sed -i '/^dependencies = \[/a"starlette>=1.3.1",' "${SRC}/pyproject.toml"

# pydantic-settings is a transitive dep from mcp — GHSA-4xgf-cpjx-pc3j
sed -i '/^dependencies = \[/a"pydantic-settings>=2.14.2",' "${SRC}/pyproject.toml"

# Pin mcp to <2.0.0 until upstream git-mcp supports the MCP SDK 2.x API
printf '\n[tool.uv]\nconstraint-dependencies = ["mcp<2.0.0"]\n' >> "${SRC}/pyproject.toml"

cd "${SRC}"
rm -f .python-version

# Upstream monorepo tags may leave src/git/pyproject.toml on a stale SemVer
# while the tree matches the CalVer tag; align for scanners.
sed -i "s/^version = \".*\"/version = \"${VERSION}\"/" pyproject.toml
grep -E '^version = ' pyproject.toml

export UV_PYTHON="${PYTHON_BIN}"
export UV_PYTHON_DOWNLOADS=never
export UV_PROJECT_ENVIRONMENT="${VENV}"
export UV_COMPILE_BYTECODE="${UV_COMPILE_BYTECODE:-1}"

uv lock --upgrade
uv sync --locked --no-install-project --no-dev --no-editable
uv sync --locked --no-dev --no-editable

find "${VENV}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} + || true

test -e "${TARGET_DIR}/usr/lib/git-mcp/bin/mcp-server-git"
ln -sf ../lib/git-mcp/bin/mcp-server-git "${TARGET_DIR}/usr/bin/mcp-server-git"

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

mkdir -p /opt/docker/sbom/git-mcp
chmod -R 0777 /opt/docker/sbom
