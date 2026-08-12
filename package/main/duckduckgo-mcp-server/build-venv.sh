#!/bin/bash
# Shared duckduckgo-mcp-server venv staging for alpine and debian leaves.
# Exported by the definition pipeline (melange vars are not expanded here):
#   SOURCE_DIR  - work dir containing src/ (upstream checkout)
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.14)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

SRC="${SOURCE_DIR}/src"
VENV="${TARGET_DIR}/usr/lib/duckduckgo-mcp-server"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

cd "${SRC}"
rm -f .python-version
export UV_PYTHON="${PYTHON_BIN}"
export UV_PYTHON_DOWNLOADS=never
export UV_PROJECT_ENVIRONMENT="${VENV}"
export UV_COMPILE_BYTECODE="${UV_COMPILE_BYTECODE:-1}"

# Install strictly from upstream's committed uv.lock plus the targeted CVE
# bumps below. Do NOT run a full `uv lock --upgrade`: regenerating the whole
# lock would drift from the dependency set the release was tested against.
# CVE-2026-59950 / CVE-2026-52869 / CVE-2026-52870: mcp <1.28.1.
# GHSA-4xgf-cpjx-pc3j: pydantic-settings 2.14.1 path traversal.
# CVE-2026-32597 / CVE-2026-48526: pyjwt <2.13.0.
# CVE-2026-42561 / CVE-2026-53539: python-multipart <0.0.31.
# CVE-2026-48818 / CVE-2026-54283: starlette <1.3.1.
# CVE-2026-49476 / CVE-2026-49477: soupsieve <2.8.4.
# CVE-2026-7246: click <8.3.3.
# GHSA-537C-GMF6-5CCF: cryptography <48.0.1.
uv lock \
  --upgrade-package "mcp==1.28.1" \
  --upgrade-package "pydantic-settings>=2.14.2" \
  --upgrade-package "pyjwt>=2.13.0" \
  --upgrade-package "python-multipart>=0.0.31" \
  --upgrade-package "starlette>=1.3.1" \
  --upgrade-package "soupsieve>=2.8.4" \
  --upgrade-package "click>=8.3.3" \
  --upgrade-package "cryptography>=48.0.1"
uv sync --locked --no-install-project --no-dev --no-editable
uv sync --locked --no-dev --no-editable

find "${VENV}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} + || true

test -e "${TARGET_DIR}/usr/lib/duckduckgo-mcp-server/bin/duckduckgo-mcp-server"
ln -sf ../lib/duckduckgo-mcp-server/bin/duckduckgo-mcp-server "${TARGET_DIR}/usr/bin/duckduckgo-mcp-server"

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

mkdir -p /opt/docker/sbom/duckduckgo-mcp-server
chmod -R 0777 /opt/docker/sbom
