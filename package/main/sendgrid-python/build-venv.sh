#!/bin/bash
# Shared sendgrid-python venv staging for the debian and alpine leaves.
# sendgrid is a pure-Python library with no console entrypoint; the venv exists
# so the consuming image can expose an interpreter with `import sendgrid`
# available together with its runtime deps (python-http-client, cryptography,
# werkzeug).
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - checkout containing src/ (upstream sendgrid-python at the
#                 pinned tag) and requirements.txt (pinned runtime deps)
#   TARGET_DIR  - package root (venv lands at ${TARGET_DIR}/usr/lib/sendgrid-python)
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.14)
#   NO_BINARY   - optional, space-separated requirements to build from source
#                 instead of installing their wheel (cryptography on the debian
#                 leaf, so it links the system OpenSSL)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

NO_BINARY_ARGS=()
for pkg in ${NO_BINARY:-}; do
  NO_BINARY_ARGS+=(--no-binary "${pkg}")
done

VENV="${TARGET_DIR}/usr/lib/sendgrid-python"
mkdir -p "${TARGET_DIR}/usr/lib"

export UV_PYTHON_DOWNLOADS=never
export UV_COMPILE_BYTECODE="${UV_COMPILE_BYTECODE:-1}"

uv venv --python "${PYTHON_BIN}" "${VENV}"
# Install the runtime deps from the pinned requirements, then sendgrid itself
# from the pinned upstream source. Both use --no-deps so nothing is resolved at
# an unpinned "latest" — the versions in requirements.txt are the only inputs.
uv pip install --python "${VENV}/bin/python" --no-deps "${NO_BINARY_ARGS[@]}" -r "${SOURCE_DIR}/requirements.txt"
uv pip install --python "${VENV}/bin/python" --no-deps "${SOURCE_DIR}/src"

# sendgrid's setup.py ships its own top-level `test` package; drop it (and any
# stray top-level tests dir) so it does not pollute the runtime venv namespace.
purelib="$("${VENV}/bin/python" -c 'import sysconfig; print(sysconfig.get_paths()["purelib"])')"
rm -rf "${purelib}/test" "${purelib}/tests"

# Trim byte-compiled caches to keep the payload lean, and drop uv's world-writable
# venv lock handle — it is inert at runtime (uv is not installed) but a needless
# write grant inside the app tree.
find "${VENV}" -depth -type d -name __pycache__ -exec rm -rf {} + || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete
rm -f "${VENV}/.lock"

# uv bakes the build-time TARGET_DIR into venv bin scripts — shebangs and the
# VIRTUAL_ENV=/activate paths in the activate* wrappers. Strip that prefix from
# every regular bin script (skip the interpreter symlinks) so they resolve to
# the final /usr/lib/sendgrid-python install path.
for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  [ -L "$f" ] && continue
  sed -i "s|${TARGET_DIR}||g" "$f"
done

mkdir -p /opt/docker/sbom/sendgrid-python
chmod -R 0777 /opt/docker/sbom
