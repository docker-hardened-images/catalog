#!/bin/bash
# Shared couchbase-mcp venv staging for the alpine and debian leaves.
# Exported by the definition pipeline (melange vars are not expanded here):
#   SOURCE_DIR - work dir containing source/ (verified upstream checkout)
#   TARGET_DIR - package root
#   PYTHON_BIN - interpreter path (e.g. /usr/bin/python3.14)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

SRC="${SOURCE_DIR}/source"
VENV="${TARGET_DIR}/opt/couchbase-mcp"

mkdir -p "${TARGET_DIR}/opt" "${TARGET_DIR}/usr/bin"

cd "${SRC}"
rm -f .python-version
export UV_PYTHON="${PYTHON_BIN}"
export UV_PYTHON_DOWNLOADS=never
export UV_PROJECT_ENVIRONMENT="${VENV}"
export UV_COMPILE_BYTECODE="${UV_COMPILE_BYTECODE:-1}"

# Install strictly from upstream's committed uv.lock plus the targeted CVE
# bumps below. Do NOT run a full `uv lock --upgrade`: regenerating the whole
# lock would drift from the dependency set the release was tested against.
# `uv sync` builds a venv without seeding pip, so no build tooling lands in
# the payload.
# CVE-2026-59950: mcp <1.28.1 misses WebSocket origin validation.
# GHSA-4xgf-cpjx-pc3j: pydantic-settings 2.14.1 path traversal.
uv lock --upgrade-package "mcp==1.28.1" --upgrade-package "pydantic-settings>=2.14.2"
uv sync --locked --no-dev --no-editable

# Drop caches/tests from the shipped venv. Prune the directory branch so -exec
# applies to it (a trailing -o file branch would otherwise capture -exec alone),
# then remove any stray bytecode separately.
find "${VENV}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} + || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

# Relative symlink so apk/dpkg --root installs (the buildpkg tests) resolve it
# under the chroot; an absolute /opt/... target breaks -e checks there.
test -e "${VENV}/bin/couchbase-mcp-server"
ln -sf ../../opt/couchbase-mcp/bin/couchbase-mcp-server "${TARGET_DIR}/usr/bin/couchbase-mcp-server"

# uv may bake the build-time staging path into generated script shebangs;
# normalize them to the final runtime path.
for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

mkdir -p /opt/docker/sbom/couchbase-mcp
chmod -R 0777 /opt/docker/sbom
