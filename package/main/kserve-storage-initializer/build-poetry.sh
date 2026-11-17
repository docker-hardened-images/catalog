#!/bin/bash
# Stages the KServe storage-initializer poetry venv under /usr/lib/kserve-storage-initializer.
# The entrypoint shebang points at that FHS interpreter. /opt/kserve compatibility
# is an image symlink, not a path this package owns.
# Exported by the definition pipeline:
#   SOURCE_DIR  - work dir containing kserve/ (verified upstream checkout)
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.11)
#   POETRY_VERSION
#   PYTHON_MAJOR_MINOR_VERSION - e.g. 3.11
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${POETRY_VERSION:?POETRY_VERSION is required}"
: "${PYTHON_MAJOR_MINOR_VERSION:?PYTHON_MAJOR_MINOR_VERSION is required}"

SRC="${SOURCE_DIR}/kserve"
PKG_LIB="${TARGET_DIR}/usr/lib/kserve-storage-initializer"
VENV="${PKG_LIB}/storage-initializer-env"
POETRY_HOME="${SOURCE_DIR}/.poetry-home"
ENTRYPOINT="${TARGET_DIR}/usr/bin/kserve-storage-initializer-entrypoint"

mkdir -p "${PKG_LIB}" "${TARGET_DIR}/usr/bin"

export CPPFLAGS="${CPPFLAGS:-} $(/usr/bin/python${PYTHON_MAJOR_MINOR_VERSION}-config --includes 2>/dev/null || true)"
export LDFLAGS="${LDFLAGS:-} $(/usr/bin/python${PYTHON_MAJOR_MINOR_VERSION}-config --ldflags 2>/dev/null || true)"

export POETRY_HOME
export VIRTUAL_ENV="${VENV}"
export PATH="${VENV}/bin:${POETRY_HOME}/bin:${PATH}"
export UV_PYTHON_DOWNLOADS=never

"${PYTHON_BIN}" -m venv "${POETRY_HOME}"
"${POETRY_HOME}/bin/pip" install "poetry==${POETRY_VERSION}"

"${PYTHON_BIN}" -m venv "${VENV}"
cp -r "${SRC}/python/kserve" "${PKG_LIB}/kserve-python"

# Match the pre-cutover image: poetry install of the storage extra, no --sync.
poetry install --no-interaction --extras storage --project "${PKG_LIB}/kserve-python"

# Overrides are a hashed lock, not ranges resolved against the index.
uv pip install --python "${VENV}/bin/python" --no-cache --no-deps --require-hashes \
  --build-constraints "${SOURCE_DIR}/build-constraints.txt" \
  --reinstall \
  -r "${SOURCE_DIR}/requirements-overrides.txt"

"${VENV}/bin/pip" uninstall --yes pip

# These build-time resolver manifests describe the upstream environment before
# the overrides above and are not used by the installed application.
# uv.lock is copied from the v0.21.0 tree; poetry install writes poetry.lock.
# rm fails the build if either file is missing.
rm "${PKG_LIB}/kserve-python/poetry.lock" "${PKG_LIB}/kserve-python/uv.lock"

PTH="${VENV}/lib/python${PYTHON_MAJOR_MINOR_VERSION}/site-packages/kserve.pth"
sed -i "s#^${TARGET_DIR}##" "${PTH}"

sed '1c#!/usr/lib/kserve-storage-initializer/storage-initializer-env/bin/python3' \
  "${SRC}/python/storage-initializer/scripts/initializer-entrypoint" \
  > "${ENTRYPOINT}"
chmod +x "${ENTRYPOINT}"

find "${PKG_LIB}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} + || true
find "${PKG_LIB}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

test -x "${ENTRYPOINT}"
head -1 "${ENTRYPOINT}" | grep -qx '#!/usr/lib/kserve-storage-initializer/storage-initializer-env/bin/python3'
