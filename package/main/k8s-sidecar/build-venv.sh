#!/bin/bash
# Shared k8s-sidecar venv staging for alpine and debian leaves.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing src/ (upstream checkout)
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.14)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

SRC="${SOURCE_DIR}/src"
VENV="${TARGET_DIR}/usr/lib/k8s-sidecar/.venv"

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

cd "${SRC}"

"${PYTHON_BIN}" -m venv --without-pip "${VENV}"
"${PYTHON_BIN}" -m pip --python "${VENV}/bin/python" install --no-cache-dir --upgrade "pip==26.2"
"${VENV}/bin/python" -m pip install --no-cache-dir .
"${VENV}/bin/python" -m pip install --no-cache-dir "urllib3==2.7.0"
"${VENV}/bin/python" -m pip install --no-cache-dir "cryptography==50.0.0"

find "${VENV}" \( -type d \( -name test -o -name tests -o -name __pycache__ \) -prune -exec rm -rf {} + \) || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

cat > "${TARGET_DIR}/usr/bin/k8s-sidecar" <<EOF
#!/bin/sh
exec /usr/lib/k8s-sidecar/.venv/bin/python -u -m sidecar "\$@"
EOF
chmod +x "${TARGET_DIR}/usr/bin/k8s-sidecar"

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done

mkdir -p /opt/docker/sbom/k8s-sidecar
chmod -R 0777 /opt/docker/sbom
