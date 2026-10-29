#!/bin/bash
# Shared datahub-actions venv staging for debian.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing datahub-src/ monorepo checkout
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

# overrides: urllib3 >= 2.8.0 (CVE-2026-97689, CVE-2026-97687, CVE-2026-97688,
# CVE-2026-44431, CVE-2026-21441, CVE-2025-66471, CVE-2025-66418),
# lxml >= 6.1.0 (CVE-2026-41066),
# cryptography >= 50.0.0 (CVE-2026-69247, CVE-2026-69249, CVE-2026-69248),
# msgpack >= 1.2.3 (CVE-2026-114613),
# setuptools >= 84.1.0 (CVE-2026-59890, GHSA-xmj3-9gf7-h52w),
# certifi >= 2026.10.19 (GHSA-6q48-6c7w-9gw2).
# filelock 4.2.1 (CVE-2026-112940, CVE-2026-112907, CVE-2026-112913) requires
# Python>=3.11; this leaf stays on 3.10 until the image line can move with it.
# cryptography from sdist (--no-binary-package): the PyPI wheels bundle a
# vulnerable OpenSSL (GHSA-537c-gmf6-5ccf, fixed only in 48.0.1 which is
# outside datahub's <47 pin); building from source links the patched
# system OpenSSL and stays within the supported version range.
cat > "${SOURCE_DIR}/overrides.txt" << 'EOF'
urllib3>=2.8.0
lxml>=6.1.0
cryptography>=50.0.0
msgpack>=1.2.3
setuptools>=84.1.0
certifi>=2026.10.19
EOF

export UV_PYTHON_DOWNLOADS=never
export UV_LINK_MODE=copy

uv venv "${VENV}" --python "${PYTHON_BIN}"
uv pip install \
  --python "${VENV}/bin/python" \
  --override "${SOURCE_DIR}/overrides.txt" \
  --no-binary cryptography \
  "${SOURCE_DIR}/datahub-src/datahub-actions[${EXTRAS}]"

# drop caches, tests, and uv/pip build-env leaks from the shipped venv
find "${VENV}" \
  \( -type d \( -name __pycache__ -o -name test -o -name tests -o -name tmp \) -prune -exec rm -rf {} + \) || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

# Keep pip. DataHub's ingestion executor runs `python -m pip download` to
# bootstrap per-source environments (acryl-datahub base requirements). Pip
# vendors urllib3 for its own HTTP stack; Scout indexes that tree as
# pkg:pypi/urllib3 even when site-packages already has the override wheel.
sp=$(echo "${VENV}/lib"/python*/site-packages)
rm -rf "${sp}/pip/_vendor/urllib3"
cp -a "${sp}/urllib3" "${sp}/pip/_vendor/urllib3"
sed -i 's/urllib3==2\.7\.0/urllib3==2.8.0/' "${sp}/pip/_vendor/vendor.txt"
if [ -f "${sp}/pip/_vendor/bom.cdx.json" ]; then
  sed -i 's/pkg:pypi\/urllib3@2\.7\.0/pkg:pypi\/urllib3@2.8.0/g' "${sp}/pip/_vendor/bom.cdx.json"
  sed -i 's/"version": "2.7.0"/"version": "2.8.0"/' "${sp}/pip/_vendor/bom.cdx.json"
fi

# Pip vendors msgpack 1.1.2 (CVE-2026-114613); install a fixed wheel and sync vendor.
uv pip install --python "${VENV}/bin/python" 'msgpack>=1.2.3'
msgpack_ver=$("${VENV}/bin/python" -c 'import importlib.metadata as m; print(m.version("msgpack"))')
rm -rf "${sp}/pip/_vendor/msgpack"
cp -a "${sp}/msgpack" "${sp}/pip/_vendor/msgpack"
sed -i "s/msgpack==1\\.1\\.2/msgpack==${msgpack_ver}/" "${sp}/pip/_vendor/vendor.txt"
if [ -f "${sp}/pip/_vendor/bom.cdx.json" ]; then
  sed -i "s/pkg:pypi\\/msgpack@1\\.1\\.2/pkg:pypi\\/msgpack@${msgpack_ver}/g" "${sp}/pip/_vendor/bom.cdx.json"
  sed -i "s/\"version\": \"1.1.2\"/\"version\": \"${msgpack_ver}\"/" "${sp}/pip/_vendor/bom.cdx.json"
fi

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
