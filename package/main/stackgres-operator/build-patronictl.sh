#!/bin/bash
# Build one patronictl venv at the path it has once installed, shared by the
# debian and alpine leaves. The operator runs /bin/patronictl-<version> with the
# interpreter named on its shebang line, so the venv's console script keeps an
# absolute shebang and a relative link in LINK_DIR points at it.
# ${...} is not expanded here, so the definition must export:
#   SOURCE_DIR       - work dir with the patroni checkouts, the lock and the license inventory
#   TARGET_DIR       - package root
#   PYTHON_BIN       - interpreter path, e.g. /usr/bin/python3.13
#   PATRONI_MAJOR    - 4 or 3; the venv is /usr/lib/stackgres-operator/patroni-<major>
#   PATRONI_VERSION  - the patroni tag checked out under SOURCE_DIR/patroni-<major>
#   LICENSE_DIR      - package-relative license directory, e.g. usr/share/licenses/<name>
#   LINK_DIR         - package-relative directory for the patronictl-<version> link
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${PATRONI_MAJOR:?PATRONI_MAJOR is required}"
: "${PATRONI_VERSION:?PATRONI_VERSION is required}"
: "${LICENSE_DIR:?LICENSE_DIR is required}"
: "${LINK_DIR:?LINK_DIR is required}"

SRC="${SOURCE_DIR}/patroni-${PATRONI_MAJOR}"
REL_VENV="usr/lib/stackgres-operator/patroni-${PATRONI_MAJOR}"
VENV="${TARGET_DIR}/${REL_VENV}"
PYTHON_NAME="$(basename "${PYTHON_BIN}")"
LICENSES="${TARGET_DIR}/${LICENSE_DIR}/python"

test -d "${SRC}"
test ! -e "${VENV}"
mkdir -p "${TARGET_DIR}/usr/lib/stackgres-operator" "${TARGET_DIR}/${LINK_DIR}" "${LICENSES}"

normalize() {
  tr '[:upper:]' '[:lower:]' | sed -E 's/[-_.]+/-/g'
}

export UV_PYTHON_DOWNLOADS=never
export UV_LINK_MODE=copy
export OPENSSL_NO_VENDOR=1
export OPENSSL_STATIC=0

uv venv --python "${PYTHON_BIN}" "${VENV}"

# Lock only, no resolver: the same lock gives the same files. Compiled
# extensions build from source so they link the system OpenSSL, libpq, libffi
# and libyaml instead of the copies manylinux and musllinux wheels bundle.
uv pip install --python "${VENV}/bin/python" --no-cache \
  --no-deps --require-hashes \
  --build-constraints "${SOURCE_DIR}/build-constraints.txt" \
  --no-binary cryptography \
  --no-binary cffi \
  --no-binary psycopg-c \
  --no-binary psutil \
  --no-binary pyyaml \
  -r "${SOURCE_DIR}/requirements-lock.txt"
# The project is a local checkout, so there is no hash to require.
uv pip install --python "${VENV}/bin/python" --no-cache --no-deps \
  --build-constraints "${SOURCE_DIR}/build-constraints.txt" "${SRC}"
uv pip check --python "${VENV}/bin/python"

# Installed distributions must equal the lock plus patroni. importlib.metadata,
# not pip freeze, which names the local patroni checkout by URL instead of version.
sed -n -E 's/^([A-Za-z0-9][A-Za-z0-9._-]*)==([^ ]+) .*$/\1 \2/p' "${SOURCE_DIR}/requirements-lock.txt" \
  | while read -r n v; do printf '%s %s\n' "$(printf '%s' "$n" | normalize)" "$v"; done \
  > "${SOURCE_DIR}/want.txt"
printf 'patroni %s\n' "${PATRONI_VERSION}" >> "${SOURCE_DIR}/want.txt"
sort -o "${SOURCE_DIR}/want.txt" "${SOURCE_DIR}/want.txt"
test "$(wc -l < "${SOURCE_DIR}/want.txt")" -eq 25
"${VENV}/bin/python" -c 'import importlib.metadata as m; [print(d.metadata["Name"], d.version) for d in m.distributions()]' \
  | while read -r n v; do printf '%s %s\n' "$(printf '%s' "$n" | normalize)" "$v"; done \
  | sort > "${SOURCE_DIR}/have-${PATRONI_MAJOR}.txt"
diff -u "${SOURCE_DIR}/want.txt" "${SOURCE_DIR}/have-${PATRONI_MAJOR}.txt"

# The license inventory must name exactly the installed distributions.
awk -F' [|] ' -v p="${PATRONI_VERSION}" '!/^#/ && NF == 4 && ($1 != "patroni" || $2 == p) { print $1, $2 }' \
  "${SOURCE_DIR}/python-licenses.txt" | sort > "${SOURCE_DIR}/inventory.txt"
diff -u "${SOURCE_DIR}/have-${PATRONI_MAJOR}.txt" "${SOURCE_DIR}/inventory.txt"

SP="$(echo "${VENV}"/lib/python*/site-packages)"
test -d "${SP}"

# uv venv seeds no installer; fail if one arrived through the lock.
for gone in pip setuptools wheel; do
  test ! -e "${SP}/${gone}"
done

# Each installed distribution's license and notice files, under its own name.
# The venvs share the lock, so the second one finds most directories present.
while read -r n v; do
  dest="${LICENSES}/${n}-${v}"
  if [ -d "${dest}" ]; then
    test -n "$(find "${dest}" -type f -print -quit)"
    continue
  fi
  mkdir -p "${dest}"
  info=""
  for d in "${SP}"/*.dist-info; do
    base="$(basename "${d}" .dist-info)"
    if [ "$(printf '%s' "${base%-*}" | normalize)" = "${n}" ] && [ "${base##*-}" = "${v}" ]; then
      info="${d}"
    fi
  done
  test -n "${info}"
  if [ -d "${info}/licenses" ]; then
    cp -a "${info}/licenses/." "${dest}/"
  fi
  find "${info}" -maxdepth 1 -type f \( -iname 'LICEN[CS]E*' -o -iname 'COPYING*' -o -iname 'NOTICE*' -o -iname 'AUTHORS*' \) \
    -exec cp -a {} "${dest}/" \;
  if [ "${n}" = python-etcd ]; then
    cp "${SOURCE_DIR}/python-etcd-LICENSE.txt" "${dest}/LICENSE.txt"
  fi
  test -n "$(find "${dest}" -type f -print -quit)"
done < "${SOURCE_DIR}/have-${PATRONI_MAJOR}.txt"

# Each compiled extension must link the system library it was built from
# source for. Capture readelf first: grep -q stops reading early, and
# pipefail would turn readelf's SIGPIPE into a failure.
needed() {
  local pattern="$1" lib="$2" so
  so="$(find "${SP}" -path "${pattern}" -name '*.so' | head -n 1)"
  test -n "${so}"
  readelf -d "${so}" > "${SOURCE_DIR}/needed.txt"
  grep -q "Shared library: \[${lib}" "${SOURCE_DIR}/needed.txt"
}
needed '*/cryptography/hazmat/bindings/_rust*' 'libssl.so'
needed '*/psycopg_c/pq*' 'libpq.so'
needed '*/_cffi_backend*' 'libffi.so'
needed '*/yaml/_yaml*' 'libyaml'

find "${VENV}" -depth -type d \( -name __pycache__ -o -name tests -o -name test \) -prune -exec rm -rf {} +
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

# activate* and direct_url.json carry this build's directories.
rm "${VENV}"/bin/activate*
# uv's lock and cache markers and the Windows launchers have no use in an installed venv.
rm -f "${VENV}"/.gitignore "${VENV}"/.lock "${VENV}"/CACHEDIR.TAG "${VENV}"/bin/*.bat
rm "${SP}"/patroni-*.dist-info/direct_url.json
find "${SP}" -name direct_url.json -delete

for script in "${VENV}"/bin/*; do
  [ -f "${script}" ] || continue
  [ -L "${script}" ] && continue
  read -r line < "${script}" || true
  case "${line}" in
    "#!${VENV}/bin/"*) sed -i "1s|^.*$|#!/${REL_VENV}/bin/${PYTHON_NAME}|" "${script}" ;;
  esac
done
test "$(head -n 1 "${VENV}/bin/patronictl")" = "#!/${REL_VENV}/bin/${PYTHON_NAME}"
test -e "${VENV}/bin/${PYTHON_NAME}"

leaks="$(grep -rlF -e "${VENV}" -e "${SRC}" "${VENV}" || true)"
if [ -n "${leaks}" ]; then
  echo "build-time path still present in:" >&2
  echo "${leaks}" >&2
  exit 1
fi

up="$(printf '%s' "${LINK_DIR}" | sed -E 's#[^/]+#..#g')"
ln -s "${up}/${REL_VENV}/bin/patronictl" "${TARGET_DIR}/${LINK_DIR}/patronictl-${PATRONI_VERSION}"
test -e "${TARGET_DIR}/${LINK_DIR}/patronictl-${PATRONI_VERSION}"
