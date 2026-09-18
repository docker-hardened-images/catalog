#!/bin/bash
# Build the dub CLI into a venv at the path it will have once installed.
# ${...} is not expanded here, so the definition must export:
#   SOURCE_DIR  - work dir with the checkout, lock and build constraints
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path, e.g. /usr/bin/python3.13
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

SRC="${SOURCE_DIR}/confluent-docker-utils"
VENV="${TARGET_DIR}/usr/lib/confluent-docker-utils"

mkdir -p "${TARGET_DIR}/usr/bin"
cd "${SRC}"

# Test-only helpers; importing this pulls in docker and yaml. grep so we do not
# empty a file that no longer looks like that.
grep -qF 'import docker' confluent/docker_utils/__init__.py
: > confluent/docker_utils/__init__.py

# setup.py copies this into the wheel's runtime deps. Drop docker/PyYAML (their
# importers are gone). Edit, do not replace: uv pip check below fails if a line
# is missed or upstream adds a dep the lock does not have.
sed -i '/^docker~=/d;/^PyYAML~=/d' requirements.txt

# cub needs a JVM and jars this package does not ship. grep first: sed is a
# silent no-op if the line moves, and we would ship cub.
grep -qF 'cub = confluent.docker_utils.cub:main' setup.py
sed -i '/cub = confluent.docker_utils.cub:main/d' setup.py
if grep -qF 'docker_utils.cub' setup.py; then
  echo "cub entry point survived the sed" >&2
  exit 1
fi

# Only imported by the __init__.py we emptied.
test -f confluent/docker_utils/cub.py
rm confluent/docker_utils/cub.py

# compose.py is imported only by the __init__.py emptied above.
test -f confluent/docker_utils/compose.py
rm confluent/docker_utils/compose.py

# setuptools ignores setup_requires when building a wheel, so this installs
# nothing. The wheel is unchanged: confluent/**/*.py comes from MANIFEST.in.
grep -qF "setup_requires=['setuptools-git']," setup.py
sed -i "/setup_requires=\['setuptools-git'\],/d" setup.py
if grep -qF 'setup_requires' setup.py; then
  echo "setup_requires survived the sed" >&2
  exit 1
fi

# No UV_COMPILE_BYTECODE: every __pycache__ is deleted below.
export UV_PYTHON_DOWNLOADS=never

uv venv "${VENV}" --python "${PYTHON_BIN}"

# Lock only, no resolver: same VERSION/REL → same files. Hashes checked.
# build-constraints pins setuptools when an sdist has to be built.
uv pip install --python "${VENV}/bin/python" --no-cache \
  --no-deps --require-hashes \
  --build-constraints "${SOURCE_DIR}/build-constraints.txt" \
  -r "${SOURCE_DIR}/requirements-lock.txt"
# The project is a local directory, so there is no hash to require.
uv pip install --python "${VENV}/bin/python" --no-cache --no-deps \
  --build-constraints "${SOURCE_DIR}/build-constraints.txt" "${SRC}"
# Installed Requires-Dist must match the lock (missed sed, or upstream added a dep).
uv pip check --python "${VENV}/bin/python"

find "${VENV}" \( -type d -a \( -name __pycache__ -o -name test -o -name tests \) \) -prune -exec rm -rf {} +

# PATH expects /usr/bin/dub; the real file is inside the venv. Relative so the
# link still works after the apk/deb is installed (an absolute path would still
# point at this build's ${TARGET_DIR}). Fail if uv never created the script.
test -e "${VENV}/bin/dub"
ln -sf ../lib/confluent-docker-utils/bin/dub "${TARGET_DIR}/usr/bin/dub"

# Drop files that embed this build's directory, and shell helpers nobody runs:
# activate* sets VIRTUAL_ENV to ${TARGET_DIR}/..., direct_url.json records ${SRC}.
rm -f "${VENV}"/bin/activate* "${VENV}"/bin/deactivate.bat "${VENV}"/bin/pydoc.bat
rm -f "${VENV}"/lib/python*/site-packages/*.dist-info/direct_url.json

# Console scripts start with #!${TARGET_DIR}/usr/lib/.../python. Strip the
# staging prefix so the shebang is #!/usr/lib/confluent-docker-utils/bin/python.
for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

# Anything still containing the venv or checkout path would break at runtime.
# Grep those full paths, not ${TARGET_DIR} / ${SOURCE_DIR} (/out, /src): those
# strings show up in ordinary text. Long shebangs also get a line-2
# `exec /abs/python`; this grep catches that too.
leaks=$(grep -rlF -e "${VENV}" -e "${SRC}" "${VENV}" || true)
if [ -n "${leaks}" ]; then
  echo "build-time path still present in:" >&2
  echo "${leaks}" >&2
  exit 1
fi
