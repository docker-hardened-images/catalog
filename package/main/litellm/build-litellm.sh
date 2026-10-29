#!/bin/bash
# Shared litellm venv + runtime staging for the debian package leaf.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing litellm-src/ and npm-patches/
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.13)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

SRC="${SOURCE_DIR}/litellm-src"
VENV="${TARGET_DIR}/usr/lib/litellm"
APP="${TARGET_DIR}/usr/share/litellm"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin" "${APP}"

cd "${SRC}"

BUILD_VENV=$(mktemp -d)
"${PYTHON_BIN}" -m venv "${BUILD_VENV}"
# shellcheck disable=SC1091
source "${BUILD_VENV}/bin/activate"
pip install --no-cache-dir build
rm -rf dist/*
python -m build
deactivate
rm -rf "${BUILD_VENV}"

"${PYTHON_BIN}" -m venv "${VENV}"
# shellcheck disable=SC1091
source "${VENV}/bin/activate"

# cryptography builds from source so it links the system OpenSSL instead of its vendored copy.
export PIP_NO_BINARY=cryptography

WHEEL_FILES=(dist/litellm-*.whl)
if [ ${#WHEEL_FILES[@]} -gt 1 ]; then
  echo "Error: Multiple wheel files found:"
  printf '  %s\n' "${WHEEL_FILES[@]}"
  exit 1
elif [ ${#WHEEL_FILES[@]} -eq 0 ] || [ ! -f "${WHEEL_FILES[0]}" ]; then
  echo "Error: No wheel files found in dist/"
  exit 1
fi
WHEEL_FILE="${WHEEL_FILES[0]}"
pip install --no-cache-dir "${WHEEL_FILE}[proxy,extra_proxy,proxy-runtime]" 'redis==5.3.1'

pip uninstall jwt -y || true
pip uninstall PyJWT -y || true
pip install --no-cache-dir PyJWT==2.9.0

pip install --no-cache-dir --force-reinstall 'starlette>=1.3.1'
pip install --no-cache-dir --upgrade 'aiohttp>=3.12.14'
pip install --no-cache-dir --upgrade 'cryptography>=46.0.5'
pip install --no-cache-dir --upgrade 'mcp>=1.23.0'
pip install --no-cache-dir --upgrade 'fastapi-sso>=0.19.0'
pip install --no-cache-dir --upgrade 'urllib3==2.8.0'
pip install --no-cache-dir --upgrade 'certifi==2026.10.19'
pip install --no-cache-dir --upgrade 'pynacl>=1.6.2'
pip install --no-cache-dir --upgrade 'nodejs-wheel-binaries>=24.17.0'
pip install --no-cache-dir --upgrade 'python-multipart>=0.0.22'
pip install --no-cache-dir --upgrade 'orjson>=3.11.5'
pip install --no-cache-dir --upgrade 'pillow>=12.1.1'
pip install --no-cache-dir --upgrade 'python-dotenv>=1.2.2'
pip install --no-cache-dir --upgrade 'pypdf>=6.21.2'
pip install --no-cache-dir --upgrade 'pydantic-settings>=2.14.2'
pip install --no-cache-dir --upgrade \
  'opentelemetry-api==1.45.1' \
  'opentelemetry-sdk==1.45.1' \
  'opentelemetry-exporter-otlp==1.45.1' \
  'opentelemetry-instrumentation-fastapi==0.66b1'
pip install --no-cache-dir --upgrade 'setuptools==84.1.0'

apply_npm_patch() {
  local search_path="$1"
  local tarball="$2"
  local optional="${3:-0}"

  echo "Patching $search_path..."

  local tmp_dir
  tmp_dir=$(mktemp -d)
  tar -xzf "${SOURCE_DIR}/npm-patches/$tarball" -C "$tmp_dir"

  local replaced=0
  while IFS= read -r -d '' pkg_dir; do
    echo "  Replacing $pkg_dir"
    rm -rf "$pkg_dir"
    cp -r "$tmp_dir/package" "$pkg_dir"
    replaced=$((replaced + 1))
  done < <(find "$VENV/lib" -type d -path "*/nodejs_wheel/lib/node_modules/npm/node_modules/$search_path" -print0)

  rm -rf "$tmp_dir"

  if [ "$replaced" -eq 0 ]; then
    if [ "$optional" -eq 1 ]; then
      echo "  ! skipped $search_path (not present in nodejs_wheel tree)"
      return 0
    fi
    echo "Error: no nodejs_wheel paths matched for $search_path"
    exit 1
  fi
  echo "  ✓ $search_path patched successfully ($replaced path(s))"
}

apply_npm_patch "diff" "diff-8.0.3.tgz"
apply_npm_patch "tar" "tar-7.5.21.tgz"
apply_npm_patch "minimatch" "minimatch-10.2.3.tgz"
apply_npm_patch "@isaacs/brace-expansion" "isaacs-brace-expansion-5.0.1.tgz" 1
apply_npm_patch "brace-expansion" "brace-expansion-5.0.12.tgz"
apply_npm_patch "ip-address" "ip-address-10.7.4.tgz"
apply_npm_patch "postcss-selector-parser" "postcss-selector-parser-7.1.6.tgz"
apply_npm_patch "tinyglobby/node_modules/picomatch" "picomatch-4.0.4.tgz"
apply_npm_patch "undici" "undici-6.29.1.tgz"
apply_npm_patch "@sigstore/core" "sigstore-core-3.2.1.tgz"
apply_npm_patch "@sigstore/verify" "sigstore-verify-3.1.1.tgz"
apply_npm_patch "sigstore" "sigstore-4.1.1.tgz"

pip install --no-cache-dir semantic_router --no-deps

# pip vendors urllib3 for its own HTTP stack; Scout indexes that tree as
# pkg:pypi/urllib3 even when site-packages already has the fixed wheel.
# Replace the vendor copy with the pinned runtime wheel so pip keeps
# working for consuming images and the SBOM does not retain a duplicate.
sp=$(echo "${VENV}/lib"/python*/site-packages)
rm -rf "$sp/pip/_vendor/urllib3"
cp -a "$sp/urllib3" "$sp/pip/_vendor/urllib3"
sed -i 's/urllib3==2\.7\.0/urllib3==2.8.0/' "$sp/pip/_vendor/vendor.txt"
CERTIFI_VER=$("${VENV}/bin/python" -c 'import certifi; print(certifi.__version__)')
rm -rf "$sp/pip/_vendor/certifi"
cp -a "$sp/certifi" "$sp/pip/_vendor/certifi"
sed -i "s/^certifi==.*/certifi==${CERTIFI_VER}/" "$sp/pip/_vendor/vendor.txt"
SETUPTOOLS_VER=$("${VENV}/bin/python" -c 'import setuptools; print(setuptools.__version__)')
rm -rf "$sp/pip/_vendor/setuptools" "$sp/pip/_vendor/pkg_resources"
cp -a "$sp/setuptools" "$sp/pip/_vendor/setuptools"
if [ -d "$sp/pkg_resources" ]; then
  cp -a "$sp/pkg_resources" "$sp/pip/_vendor/pkg_resources"
fi
sed -i "s/^setuptools==.*/setuptools==${SETUPTOOLS_VER}/" "$sp/pip/_vendor/vendor.txt"
if [ -f "$sp/pip/_vendor/bom.cdx.json" ]; then
  sed -i 's/pkg:pypi\/urllib3@2\.7\.0/pkg:pypi\/urllib3@2.8.0/g' "$sp/pip/_vendor/bom.cdx.json"
  sed -i 's/"version": "2.7.0"/"version": "2.8.0"/' "$sp/pip/_vendor/bom.cdx.json"
  sed -i -E 's/pkg:pypi\/certifi@[0-9.]+/pkg:pypi\/certifi@'"${CERTIFI_VER}"'/g' "$sp/pip/_vendor/bom.cdx.json"
  # Pip 26.2.1 records certifi's component version separately from its PURL.
  # Rewrite both so an SBOM reader cannot keep the vendored 2026.6.17.
  sed -i 's/"version": "2026.6.17"/"version": "'"${CERTIFI_VER}"'"/' "$sp/pip/_vendor/bom.cdx.json"
  sed -i -E 's/pkg:pypi\/setuptools@[0-9.]+/pkg:pypi\/setuptools@'"${SETUPTOOLS_VER}"'/g' "$sp/pip/_vendor/bom.cdx.json"
  sed -i 's/"version": "70.3.0"/"version": "'"${SETUPTOOLS_VER}"'"/' "$sp/pip/_vendor/bom.cdx.json"
  "${VENV}/bin/python" - "$sp/pip/_vendor/bom.cdx.json" "${CERTIFI_VER}" <<'PY'
import json, sys
path, ver = sys.argv[1], sys.argv[2]
with open(path) as f:
    bom = json.load(f)
found = False
for comp in bom.get("components", []):
    if comp.get("name") != "certifi":
        continue
    found = True
    want = f"pkg:pypi/certifi@{ver}"
    if comp.get("version") != ver or comp.get("purl") != want or comp.get("bom-ref") != want:
        raise SystemExit(
            f"certifi component is version={comp.get('version')!r} purl={comp.get('purl')!r} bom-ref={comp.get('bom-ref')!r}, want {ver}"
        )
if not found:
    raise SystemExit("certifi component missing from pip vendor bom")
PY
  "${VENV}/bin/python" - "$sp/pip/_vendor/bom.cdx.json" "${SETUPTOOLS_VER}" <<'PY'
import json, sys
path, ver = sys.argv[1], sys.argv[2]
with open(path) as f:
    bom = json.load(f)
found = False
for comp in bom.get("components", []):
    if comp.get("name") != "setuptools":
        continue
    found = True
    want = f"pkg:pypi/setuptools@{ver}"
    if comp.get("version") != ver or comp.get("purl") != want or comp.get("bom-ref") != want:
        raise SystemExit(
            f"setuptools component is version={comp.get('version')!r} purl={comp.get('purl')!r} bom-ref={comp.get('bom-ref')!r}, want {ver}"
        )
if not found:
    raise SystemExit("setuptools component missing from pip vendor bom")
PY
fi
"${VENV}/bin/pip" --version

mkdir -p "${APP}/docker"
cp docker/entrypoint.sh "${APP}/docker/"
cp docker/prod_entrypoint.sh "${APP}/docker/"
cp schema.prisma "${APP}/"
chmod +x "${APP}/docker/entrypoint.sh" "${APP}/docker/prod_entrypoint.sh"

export PRISMA_HOME_DIR="${APP}"
python3 -m prisma generate --schema "${APP}/schema.prisma"

find "${VENV}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} + || true

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

test -e "${VENV}/bin/litellm"
ln -sf ../lib/litellm/bin/litellm "${TARGET_DIR}/usr/bin/litellm"

cat > "${TARGET_DIR}/usr/bin/supervisord" << 'EOF'
#!/bin/bash
echo "The 'supervisor' package is not installed in the DHI litellm image, and is not supported by default."
exit 1
EOF
chmod +x "${TARGET_DIR}/usr/bin/supervisord"

mkdir -p /opt/docker/sbom/litellm
chmod -R 0777 /opt/docker/sbom
