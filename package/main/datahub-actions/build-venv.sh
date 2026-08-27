#!/bin/bash
# Shared datahub-actions venv staging for debian.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing acryl_datahub_actions.tar.gz
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.10)
#   EXTRAS      - pip extras for acryl-datahub-actions (e.g. all)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${EXTRAS:?EXTRAS is required}"

VENV="${TARGET_DIR}/usr/lib/datahub-actions"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

# overrides: urllib3 >= 2.7.0 (CVE-2026-44431, CVE-2026-21441,
# CVE-2025-66471, CVE-2025-66418), lxml >= 6.1.0 (CVE-2026-41066),
# cryptography >= 50.0.0 (CVE-2026-69247, CVE-2026-69249, CVE-2026-69248),
# setuptools >= 83.0.0 (CVE-2026-59890).
# cryptography from sdist (--no-binary-package): the PyPI wheels bundle a
# vulnerable OpenSSL (GHSA-537c-gmf6-5ccf, fixed only in 48.0.1 which is
# outside datahub's <47 pin); building from source links the patched
# system OpenSSL and stays within the supported version range.
cat > "${SOURCE_DIR}/overrides.txt" << 'EOF'
urllib3>=2.7.0
lxml>=6.1.0
cryptography>=50.0.0
setuptools>=83.0.0
EOF

export UV_PYTHON_DOWNLOADS=never
export UV_LINK_MODE=copy

uv venv "${VENV}" --python "${PYTHON_BIN}"
uv pip install \
  --python "${VENV}/bin/python" \
  --override "${SOURCE_DIR}/overrides.txt" \
  --no-binary cryptography \
  "${SOURCE_DIR}/acryl_datahub_actions.tar.gz[${EXTRAS}]"

# drop caches, tests, and uv/pip build-env leaks from the shipped venv
find "${VENV}" \
  \( -type d \( -name __pycache__ -o -name test -o -name tests -o -name tmp \) -prune -exec rm -rf {} + \) || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

# Relative link so deb --root installs (buildpkg TestDEB) resolve under the
# chroot; absolute /usr/lib/... targets break -e path checks there.
test -e "${VENV}/bin/datahub-actions"
ln -sf ../lib/datahub-actions/bin/datahub-actions "${TARGET_DIR}/usr/bin/datahub-actions"

# pip/uv may bake the build-time path into shebangs; normalize to the final path.
for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

mkdir -p /opt/docker/sbom/datahub-actions
chmod -R 0777 /opt/docker/sbom
