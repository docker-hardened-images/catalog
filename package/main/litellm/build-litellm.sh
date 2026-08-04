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
pip install --no-cache-dir "${WHEEL_FILE}[proxy,extra_proxy,proxy-runtime]"

pip uninstall jwt -y || true
pip uninstall PyJWT -y || true
pip install --no-cache-dir PyJWT==2.9.0

pip install --no-cache-dir --force-reinstall 'starlette>=1.3.1'
pip install --no-cache-dir --upgrade 'aiohttp>=3.12.14'
pip install --no-cache-dir --upgrade 'cryptography>=46.0.5'
pip install --no-cache-dir --upgrade 'mcp>=1.23.0'
pip install --no-cache-dir --upgrade 'fastapi-sso>=0.19.0'
pip install --no-cache-dir --upgrade 'urllib3>=2.6.3'
pip install --no-cache-dir --upgrade 'pynacl>=1.6.2'
pip install --no-cache-dir --upgrade 'nodejs-wheel-binaries>=24.17.0'
pip install --no-cache-dir --upgrade 'python-multipart>=0.0.22'
pip install --no-cache-dir --upgrade 'orjson>=3.11.5'
pip install --no-cache-dir --upgrade 'pillow>=12.1.1'
pip install --no-cache-dir --upgrade 'python-dotenv>=1.2.2'
pip install --no-cache-dir --upgrade 'pypdf>=6.13.3'
pip install --no-cache-dir --upgrade 'pydantic-settings>=2.14.2'

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
apply_npm_patch "brace-expansion" "brace-expansion-5.0.9.tgz"
apply_npm_patch "ip-address" "ip-address-10.3.1.tgz"
apply_npm_patch "tinyglobby/node_modules/picomatch" "picomatch-4.0.4.tgz"
apply_npm_patch "undici" "undici-6.27.0.tgz"
apply_npm_patch "@sigstore/core" "sigstore-core-3.2.1.tgz"
apply_npm_patch "@sigstore/verify" "sigstore-verify-3.1.1.tgz"
apply_npm_patch "sigstore" "sigstore-4.1.1.tgz"

pip install --no-cache-dir semantic_router --no-deps

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
