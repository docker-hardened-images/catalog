#!/bin/bash
# Build the volumes web app venv at the path it will have once installed.
# The native extensions are compiled here against the distro's libraries
# instead of installing wheels that carry static or vendored copies.
# ${...} is not expanded here, so the definition must export:
#   SOURCE_DIR  - work dir with the checkout, lock and build constraints
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path, e.g. /usr/bin/python3.12
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

BACKEND="${SOURCE_DIR}/notebooks/components/crud-web-apps/common/backend"
VENV="${TARGET_DIR}/usr/lib/kubeflow-volumes-web-app/venv"

export UV_PYTHON_DOWNLOADS=never
export UV_LINK_MODE=copy

# cryptography: link the system OpenSSL, and refuse any crate resolution that
# differs from the sdist's Cargo.lock. The crate sources land in CARGO_HOME,
# where the stage crate notices step reads their license files.
export OPENSSL_NO_VENDOR=1
export OPENSSL_STATIC=0
export MATURIN_PEP517_ARGS=--locked
export CARGO_HOME="${SOURCE_DIR}/cargo-home"
# rustc embeds crate source paths in panic locations; without this the .so
# names this build's CARGO_HOME.
export RUSTFLAGS="--remap-path-prefix=${CARGO_HOME}=/cargo"
# PyYAML: fail instead of silently building the pure-Python fallback.
export PYYAML_FORCE_LIBYAML=1
# gevent: link the system libev, libuv and c-ares instead of embedding them.
export GEVENTSETUP_EMBED=0

uv venv "${VENV}" --python "${PYTHON_BIN}"

uv pip install --python "${VENV}/bin/python" --no-cache \
  --no-deps --require-hashes \
  --build-constraints "${SOURCE_DIR}/build-constraints.txt" \
  --no-binary cryptography,cffi,pyyaml,gevent,greenlet \
  -r "${SOURCE_DIR}/requirements-lock.txt"
# The common backend is a directory in the checkout, so there is no hash to
# require. Its distribution name must stay `kubeflow`: the metrics endpoint
# reads importlib.metadata.version("kubeflow") at startup.
uv pip install --python "${VENV}/bin/python" --no-cache --no-deps \
  --build-constraints "${SOURCE_DIR}/build-constraints.txt" "${BACKEND}"
# Installed Requires-Dist must match the lock (upstream added or changed a dep).
uv pip check --python "${VENV}/bin/python"
"${VENV}/bin/python" -c 'import importlib.metadata as m; assert m.version("kubeflow") == "1.2", m.version("kubeflow")'
test -x "${VENV}/bin/gunicorn"

site="$("${VENV}/bin/python" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
test -d "${site}"
# auditwheel's vendored-library directories mean a wheel slipped past
# --no-binary.
libs=$(find "${site}" -maxdepth 1 -type d -name '*.libs')
if [ -n "${libs}" ]; then
  echo "vendored shared libraries in the venv: ${libs}" >&2
  exit 1
fi

# greenlet ships compiled test extensions under greenlet/tests.
find "${VENV}" \( -type d -a \( -name __pycache__ -o -name tests -o -name testing \) \) -prune -exec rm -rf {} +

# activate* sets VIRTUAL_ENV to ${TARGET_DIR}/..., direct_url.json records the
# checkout path, and .lock is uv's handle on the venv.
rm "${VENV}"/bin/activate* "${VENV}"/bin/deactivate.bat "${VENV}"/bin/pydoc.bat
rm "${VENV}/.lock"
rm "${site}/kubeflow-1.2.dist-info/direct_url.json"
if find "${site}" -maxdepth 2 -path '*.dist-info/direct_url.json' | grep -q .; then
  echo "direct_url.json left in the venv" >&2
  exit 1
fi

# Console scripts start with #!${TARGET_DIR}/usr/lib/.../python. Strip the
# staging prefix so the shebang is the installed venv python.
for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  [ -L "$f" ] && continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done
head -n1 "${VENV}/bin/gunicorn" | grep -qxF '#!/usr/lib/kubeflow-volumes-web-app/venv/bin/python'

# Anything still naming the staging venv, the checkout or the crate cache
# would point at paths that do not exist once installed.
leaks=$(grep -rlF -e "${VENV}" -e "${SOURCE_DIR}/notebooks" -e "${CARGO_HOME}" "${VENV}" || true)
if [ -n "${leaks}" ]; then
  echo "build-time path still present in:" >&2
  echo "${leaks}" >&2
  exit 1
fi
