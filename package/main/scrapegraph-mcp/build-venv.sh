#!/bin/bash
# Build scrapegraph-mcp into the final FHS venv path used by the package.
# Expects SOURCE_DIR, TARGET_DIR, and PYTHON_BIN from the definition pipeline.
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

SRC="${SOURCE_DIR}/scrapegraph-mcp"
VENV="${TARGET_DIR}/usr/lib/scrapegraph-mcp"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

cd "${SRC}"
rm -rf .git

export UV_PYTHON="${PYTHON_BIN}"
export UV_PYTHON_DOWNLOADS=never
export UV_PROJECT_ENVIRONMENT="${VENV}"
export UV_COMPILE_BYTECODE="${UV_COMPILE_BYTECODE:-1}"

# Build cryptography from source instead of installing the manylinux wheel. The
# wheel statically bundles its own OpenSSL, which would then only be patchable
# by waiting on a cryptography respin; a source build links the distro
# libssl/libcrypto, so OpenSSL CVEs are fixed by a base image bump. This is why
# build-essential, cargo, rustc, pkg-config and libssl-dev are in the build
# closure -- do not "simplify" them away.
export UV_NO_BINARY_PACKAGE=cryptography

# Install strictly from upstream's committed uv.lock plus the targeted CVE bumps
# below. Do NOT run a full `uv lock --upgrade`: regenerating the whole lock would
# drift from the dependency set the release was tested against and would make the
# artifact behind a given tag non-reproducible across rebuilds.
# Pins are exact, not floors: `--upgrade-package "fastmcp>=3.2.0"` would resolve
# to whatever is newest at build time, so the closure behind a given tag would
# still move between rebuilds. Bump these deliberately when the next CVE lands.
# fastmcp 3.4.7 clears CVE-2025-64340, CVE-2026-27124, CVE-2026-32871 (all fixed
#   in 3.2.0; no 2.x backport exists, so this crosses the 3.x major boundary).
# starlette 1.6.0 clears CVE-2026-48710, CVE-2026-48817, CVE-2026-48818,
#   CVE-2026-54282, CVE-2026-54283 (highest floor is 1.3.1).
# cryptography 50.0.0 clears CVE-2026-69247, CVE-2026-69249.
# The rest are packages upstream's lock pins to vulnerable versions. Because we
# install from that lock rather than re-resolving the world, each needs naming
# here explicitly -- a full `uv lock --upgrade` would sweep them up as a side
# effect, but at the cost of an unreproducible closure.
# urllib3 2.7.0 clears CVE-2025-66418, CVE-2025-66471, CVE-2026-21441,
#   CVE-2026-44431 (highest floor is 2.7.0).
# click 8.3.3 clears CVE-2026-7246.
# requests 2.33.0 clears CVE-2026-25645.
# idna 3.15 clears CVE-2026-45409.
# python-dotenv 1.2.2 clears CVE-2026-28684.
# pygments 2.20.0 clears CVE-2026-4539 (LOW).
uv lock \
  --upgrade-package "fastmcp==3.4.7" \
  --upgrade-package "starlette==1.6.0" \
  --upgrade-package "cryptography==50.0.0" \
  --upgrade-package "urllib3==2.7.0" \
  --upgrade-package "click==8.3.3" \
  --upgrade-package "requests==2.33.0" \
  --upgrade-package "idna==3.15" \
  --upgrade-package "python-dotenv==1.2.2" \
  --upgrade-package "pygments==2.20.0"
uv sync --locked --no-dev --no-editable

find "${VENV}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} + || true
find "${VENV}" \( -type f -a \( -name '*.pyc' -o -name '*.pyo' \) \) -delete || true

# Relative symlink so dpkg --root installs (the buildpkg tests) resolve it under
# the chroot; an absolute /usr/... target breaks -e checks there.
test -e "${VENV}/bin/scrapegraph-mcp"
ln -sf ../lib/scrapegraph-mcp/bin/scrapegraph-mcp "${TARGET_DIR}/usr/bin/scrapegraph-mcp"

# uv may bake the build-time staging path into generated script shebangs;
# normalize them to the final runtime path.
for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done
