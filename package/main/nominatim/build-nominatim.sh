#!/bin/bash
# Stage Nominatim into a venv at the path it will have once installed.
# Melange does not expand ${...} in this file. The pipeline exports:
#   SOURCE_DIR          work dir with the unpacked release and the lock
#   TARGET_DIR          package root
#   PYTHON_BIN          distro interpreter, /usr/bin/python3.14
#   LOCK_FILE           hashed runtime requirements for this minor
#   BUILD_LOCK_FILE     hashed PEP 517 build backends shared by every minor
#   NOMINATIM_VERSION   upstream version, for example 5.3.2
#   LIBOSMIUM_VERSION   libosmium headers compiled into the osmium extension
#   PROTOZERO_VERSION   protozero headers compiled into the osmium extension
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${LOCK_FILE:?LOCK_FILE is required}"
: "${BUILD_LOCK_FILE:?BUILD_LOCK_FILE is required}"
: "${NOMINATIM_VERSION:?NOMINATIM_VERSION is required}"
: "${LIBOSMIUM_VERSION:?LIBOSMIUM_VERSION is required}"
: "${PROTOZERO_VERSION:?PROTOZERO_VERSION is required}"

test -x "${PYTHON_BIN}"
test -f "${LOCK_FILE}"
test -f "${BUILD_LOCK_FILE}"
test -f "${SOURCE_DIR}/libosmium.tar.gz"
test -f "${SOURCE_DIR}/protozero.tar.gz"

SRC="${SOURCE_DIR}/nominatim-src"
VENV="${TARGET_DIR}/usr/lib/nominatim"

test -f "${SRC}/packaging/nominatim-db/pyproject.toml"
test -f "${SRC}/packaging/nominatim-api/pyproject.toml"
test -f "${SRC}/data/country_osm_grid.sql.gz"
test -d "${SRC}/packaging/nominatim-db/lib-sql"
test -d "${SRC}/packaging/nominatim-db/lib-lua"
test -f "${SRC}/COPYING"
test -d "${SRC}/LICENSES"

tar -xzf "${SOURCE_DIR}/protozero.tar.gz" -C "${SOURCE_DIR}"
tar -xzf "${SOURCE_DIR}/libosmium.tar.gz" -C "${SOURCE_DIR}"
test -d "${SOURCE_DIR}/protozero-${PROTOZERO_VERSION}"
test -d "${SOURCE_DIR}/libosmium-${LIBOSMIUM_VERSION}"

# pyosmium's FindOsmium/FindProtozero search these prefixes before the
# copy vendored inside the sdist. Point them at the tracked tarballs.
export LIBOSMIUM_PREFIX="${SOURCE_DIR}/libosmium-${LIBOSMIUM_VERSION}"
export PROTOZERO_PREFIX="${SOURCE_DIR}/protozero-${PROTOZERO_VERSION}"
grep -q "LIBOSMIUM_VERSION_STRING \"${LIBOSMIUM_VERSION}\"" "${LIBOSMIUM_PREFIX}/include/osmium/version.hpp"
grep -q "PROTOZERO_VERSION_STRING \"${PROTOZERO_VERSION}\"" "${PROTOZERO_PREFIX}/include/protozero/version.hpp"

mkdir -p "${TARGET_DIR}/usr/bin" "${TARGET_DIR}/usr/share/doc/nominatim"
cp -a "${SRC}/COPYING" "${SRC}/README.md" "${TARGET_DIR}/usr/share/doc/nominatim/"
cp -a "${SRC}/LICENSES" "${TARGET_DIR}/usr/share/doc/nominatim/LICENSES"
test -f "${TARGET_DIR}/usr/share/doc/nominatim/COPYING"
test -f "${TARGET_DIR}/usr/share/doc/nominatim/LICENSES/Apache-2.0.txt"
test -f "${TARGET_DIR}/usr/share/doc/nominatim/LICENSES/GPL-2.0-only.txt"

export UV_PYTHON="${PYTHON_BIN}"
export UV_PYTHON_DOWNLOADS=never
export PYTHONDONTWRITEBYTECODE=1
export CMAKE_GENERATOR="Unix Makefiles"
export CMAKE_ARGS="-DWITH_LZ4=OFF"

uv venv "${VENV}" --python "${PYTHON_BIN}"

# Build backends are wheels, pinned and hashed. --only-binary refuses an sdist
# so this step cannot grow a second unpinned resolver.
uv pip install --python "${VENV}/bin/python" --no-cache --require-hashes --only-binary :all: \
  -r "${BUILD_LOCK_FILE}"

# --no-build-isolation uses the backends just installed. Isolated builds would
# resolve scikit-build-core, pybind11, setuptools, wheel, Cython, and hatchling
# from ranges that are not in the runtime lock.
uv pip install --python "${VENV}/bin/python" --no-cache --require-hashes --no-build-isolation \
  --no-binary pyicu --no-binary psycopg-c --no-binary osmium --no-binary datrie \
  -r "${LOCK_FILE}"

# Hatch's sdist excludes these and force-includes a replacement. A direct
# wheel build does not apply the sdist exclude, so both copies hit one path.
for generated in \
  "${SRC}/packaging/nominatim-db/src/nominatim_db/paths.py" \
  "${SRC}/packaging/nominatim-api/src/nominatim_api/config.py"
do
  test -f "${generated}"
  rm "${generated}"
  test ! -e "${generated}"
done
test -f "${SRC}/packaging/nominatim-db/extra_src/nominatim_db/paths.py"
test -f "${SRC}/packaging/nominatim-api/extra_src/paths.py"
test -f "${SRC}/packaging/nominatim-api/src/nominatim_db/config.py"

uv pip install --python "${VENV}/bin/python" --no-cache --no-deps --no-build-isolation \
  "${SRC}/packaging/nominatim-db" \
  "${SRC}/packaging/nominatim-api"

# The build lock is not a runtime dependency. Remove every name it added that
# the runtime lock does not also pin, and fail if any of those names remain.
build_only=$("${PYTHON_BIN}" - "${BUILD_LOCK_FILE}" "${LOCK_FILE}" <<'PY'
import re
import sys
from pathlib import Path

def names(path):
    found = {}
    for line in Path(path).read_text().splitlines():
        match = re.match(r"^([A-Za-z0-9_.-]+)==", line)
        if match:
            raw = match.group(1)
            found[raw.lower().replace("_", "-")] = raw
    return found

build = names(sys.argv[1])
runtime = names(sys.argv[2])
extra = [build[key] for key in sorted(set(build) - set(runtime))]
if not extra:
    raise SystemExit("build lock added no package beyond the runtime lock")
print(" ".join(extra))
PY
)
# shellcheck disable=SC2086
uv pip uninstall --python "${VENV}/bin/python" ${build_only}
for name in ${build_only}; do
  if uv pip show --python "${VENV}/bin/python" "${name}" >/dev/null 2>&1; then
    echo "build-only package still installed: ${name}" >&2
    exit 1
  fi
done

uv pip check --python "${VENV}/bin/python"

version_out=$("${VENV}/bin/nominatim" --version)
printf '%s\n' "${version_out}"
case "${version_out}" in
  "Nominatim version ${NOMINATIM_VERSION}"|"Nominatim version ${NOMINATIM_VERSION}-"[0-9]*) ;;
  *)
    echo "unexpected nominatim version: ${version_out}" >&2
    exit 1
    ;;
esac

PYTHONDONTWRITEBYTECODE=1 "${VENV}/bin/python" -B -c '
import importlib.util
import sys

for name in ("psycopg_binary", "asyncpg"):
    if importlib.util.find_spec(name) is not None:
        raise SystemExit("forbidden module installed: " + name)
import psycopg
import sqlalchemy.dialects.postgresql.psycopg
import nominatim_db
import nominatim_api
import icu
import osmium
'

icu_so=$(find "${VENV}" -name '_icu*.so' -print -quit)
psycopg_so=$(find "${VENV}" -path '*psycopg_c*' -name '*.so' -print -quit)
osm_so=$(find "${VENV}" -name '_osmium*.so' -print -quit)
test -n "${icu_so}"
test -n "${psycopg_so}"
test -n "${osm_so}"

list_needed() {
  local so="$1"
  if command -v ldd >/dev/null 2>&1; then
    ldd "${so}"
    return
  fi
  # musl's loader --list exits non-zero for Python symbols an extension
  # resolves from libpython at import time. Those lines are on stderr.
  local linker out
  for linker in /lib64/ld-linux-x86-64.so.2 /lib/ld-linux-aarch64.so.1 \
    /lib/ld-musl-x86_64.so.1 /lib/ld-musl-aarch64.so.1; do
    if [ -x "${linker}" ]; then
      out=$("${linker}" --list "${so}" 2>/dev/null || true)
      if [ -n "${out}" ]; then
        printf '%s\n' "${out}"
        return
      fi
    fi
  done
  echo "no ldd or dynamic linker available to inspect ${so}" >&2
  exit 1
}

assert_system_link() {
  local so="$1"
  local soname="$2"
  local out
  out=$(list_needed "${so}")
  printf '%s\n' "${out}" | grep -q "${soname}"
  if printf '%s\n' "${out}" | grep -q 'not found'; then
    printf '%s\n' "${out}" >&2
    echo "${so} has an unresolved NEEDED entry" >&2
    exit 1
  fi
  if printf '%s\n' "${out}" | grep -q "${VENV}"; then
    printf '%s\n' "${out}" >&2
    echo "${so} links a library inside the venv" >&2
    exit 1
  fi
}

assert_system_link "${icu_so}" "libicuuc"
assert_system_link "${psycopg_so}" "libpq"
assert_system_link "${osm_so}" "libexpat"

# libosmium writes "libosmium/<version>" into the PBF generator header, so the
# version is in the extension. protozero's version macro is not referenced by
# pyosmium, so it is not in the binary; the header grep above is that pin.
if ! grep -aqF "libosmium/${LIBOSMIUM_VERSION}" "${osm_so}"; then
  echo "libosmium ${LIBOSMIUM_VERSION} is not present in ${osm_so}" >&2
  exit 1
fi

"${VENV}/bin/python" -B -c '
import nominatim_db.paths as p
grid = p.DATA_DIR / "country_osm_grid.sql.gz"
words = p.DATA_DIR / "words.sql"
if not grid.is_file():
    raise SystemExit("missing country grid: " + str(grid))
if not words.is_file():
    raise SystemExit("missing words.sql: " + str(words))
if not any(p.SQLLIB_DIR.glob("*.sql")):
    raise SystemExit("no SQL files in " + str(p.SQLLIB_DIR))
if not any(p.LUALIB_DIR.rglob("*.lua")):
    raise SystemExit("no Lua files in " + str(p.LUALIB_DIR))
if not p.CONFIG_DIR.is_dir():
    raise SystemExit("missing settings dir: " + str(p.CONFIG_DIR))
'

drop_list=$(find "${VENV}" -depth \( -type d -name __pycache__ -o -type d -name tests -o -type d -name test -o -type f -name '*.pyc' -o -type f -name direct_url.json \) -print)
if [ -n "${drop_list}" ]; then
  printf '%s\n' "${drop_list}" | while IFS= read -r path; do
    test -e "${path}"
    rm -r "${path}"
  done
fi
if find "${VENV}" \( -type d -name __pycache__ -o -type f -name '*.pyc' \) -print -quit | grep -q .; then
  echo "pyc files remain under ${VENV}" >&2
  exit 1
fi

test -e "${VENV}/bin/nominatim"
test -e "${VENV}/bin/gunicorn"
test -e "${VENV}/bin/uvicorn"
ln -sf ../lib/nominatim/bin/nominatim "${TARGET_DIR}/usr/bin/nominatim"

for script in "${VENV}/bin"/*; do
  test -f "${script}" || continue
  read -r line < "${script}" || true
  case "${line}" in
    "#!${TARGET_DIR}"*)
      sed -i "1s|#!${TARGET_DIR}|#!|" "${script}"
      ;;
  esac
done

if [ -f "${VENV}/pyvenv.cfg" ] && grep -q "${TARGET_DIR}" "${VENV}/pyvenv.cfg"; then
  sed -i "s|${TARGET_DIR}||g" "${VENV}/pyvenv.cfg"
  grep -q '^home = ' "${VENV}/pyvenv.cfg"
fi

for extra in activate activate.csh activate.fish activate.nu activate.bat Activate.ps1 deactivate.bat pydoc.bat; do
  if [ -f "${VENV}/bin/${extra}" ]; then
    rm "${VENV}/bin/${extra}"
  fi
done

leaks=$(grep -rlF --binary-files=without-match -e "${TARGET_DIR}/" -e "${SRC}" "${VENV}" || true)
if [ -n "${leaks}" ]; then
  echo "build-time path still present in:" >&2
  printf '%s\n' "${leaks}" >&2
  exit 1
fi
