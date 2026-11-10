#!/bin/bash
# Shared datahub-actions venv staging for debian.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing datahub-src/ monorepo checkout
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.11)
#   EXTRAS      - pip extras for acryl-datahub-actions (e.g. all)
#   ACTIONS_VERSION        - release version written into datahub-actions
#   ACRYL_DATAHUB_VERSION  - pinned acryl-datahub release (sdist at SOURCE_DIR)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${EXTRAS:?EXTRAS is required}"
: "${ACTIONS_VERSION:?ACTIONS_VERSION is required}"
: "${ACRYL_DATAHUB_VERSION:?ACRYL_DATAHUB_VERSION is required}"

test -f "${SOURCE_DIR}/acryl_datahub.tar.gz"

VENV="${TARGET_DIR}/usr/lib/datahub-actions"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

# overrides: urllib3 >= 2.8.0 (CVE-2026-97689, CVE-2026-97687, CVE-2026-97688,
# CVE-2026-44431, CVE-2026-21441, CVE-2025-66471, CVE-2025-66418),
# lxml >= 6.1.0 (CVE-2026-41066),
# cryptography >= 50.0.0 (CVE-2026-69247, CVE-2026-69249, CVE-2026-69248),
# msgpack >= 1.2.3 (CVE-2026-114613),
# setuptools >= 84.1.0 (CVE-2026-59890, GHSA-xmj3-9gf7-h52w),
# certifi >= 2026.10.19 (GHSA-6q48-6c7w-9gw2),
# filelock >= 4.2.1 (CVE-2026-112940, CVE-2026-112907, CVE-2026-112913, CVE-2026-112908,
# CVE-2026-112909, CVE-2026-112910, CVE-2026-112911, CVE-2026-112915, CVE-2026-112935,
# CVE-2026-112938, CVE-2026-112939, CVE-2026-112912).
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
filelock>=4.2.1
EOF

# acryl-datahub: the tag's _version.py is the 1!0.0.0.dev0 placeholder, which turns
# off datahub-actions' acryl-datahub==<version> self-pin. Once the version is set
# below, that pin is live, and PyPI has no acryl-datahub 1.7.0.1, so override it
# with the pinned sdist (same input as image/datahub-actions).
echo "acryl-datahub[datahub-kafka] @ file://${SOURCE_DIR}/acryl_datahub.tar.gz" >> "${SOURCE_DIR}/overrides.txt"

# Set the release version the way the docker build does (python-build/version_updater.py).
"${PYTHON_BIN}" "${SOURCE_DIR}/datahub-src/python-build/version_updater.py" \
  --directory "${SOURCE_DIR}/datahub-src/datahub-actions/" \
  --version "${ACTIONS_VERSION}" \
  --expected-update-count 1

export UV_PYTHON_DOWNLOADS=never
export UV_LINK_MODE=copy

uv venv "${VENV}" --python "${PYTHON_BIN}"
uv pip install \
  --python "${VENV}/bin/python" \
  --override "${SOURCE_DIR}/overrides.txt" \
  --no-binary cryptography \
  "${SOURCE_DIR}/datahub-src/datahub-actions[${EXTRAS}]"

# Fail the build if the packaged versions are not the intended ones.
installed_actions=$("${VENV}/bin/python" -c 'import importlib.metadata as m; print(m.version("acryl-datahub-actions"))')
installed_datahub=$("${VENV}/bin/python" -c 'import importlib.metadata as m; print(m.version("acryl-datahub"))')
test "${installed_actions}" = "${ACTIONS_VERSION}"
test "${installed_datahub}" = "${ACRYL_DATAHUB_VERSION}"

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
