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
"${VENV}/bin/python" -m pip install --no-cache-dir "urllib3==2.8.0"
"${VENV}/bin/python" -m pip install --no-cache-dir "certifi==2026.10.19"
"${VENV}/bin/python" -m pip install --no-cache-dir "cryptography==50.0.0"
# oauthlib 4.0.1 is the first release fixing CVE-2026-49272 (Scout fixed version 4.0.1).
"${VENV}/bin/python" -m pip install --no-cache-dir "oauthlib==4.0.1"

# pip vendors urllib3/certifi for its own HTTP stack; Scout indexes that tree
# as pkg:pypi/* even when site-packages already has the pinned wheels.
sp=$(echo "${VENV}/lib"/python*/site-packages)
rm -rf "${sp}/pip/_vendor/urllib3"
cp -a "${sp}/urllib3" "${sp}/pip/_vendor/urllib3"
sed -i 's/urllib3==2\.7\.0/urllib3==2.8.0/' "${sp}/pip/_vendor/vendor.txt"
CERTIFI_VER=$("${VENV}/bin/python" -c 'import certifi; print(certifi.__version__)')
rm -rf "${sp}/pip/_vendor/certifi"
cp -a "${sp}/certifi" "${sp}/pip/_vendor/certifi"
# pip 26.2 indents transitive rows (four spaces under requests). An
# anchored ^certifi== pattern never matches, so the stale pin would ship.
sed -i -E "s/^([[:space:]]*)certifi==.*/\1certifi==${CERTIFI_VER}/" "${sp}/pip/_vendor/vendor.txt"
pin=$(grep -E '^[[:space:]]*certifi==' "${sp}/pip/_vendor/vendor.txt" | sed -E 's/^[[:space:]]*//' || true)
if [ "${pin}" != "certifi==${CERTIFI_VER}" ]; then
  echo "pip/_vendor/vendor.txt certifi pin was not updated to ${CERTIFI_VER} (found: ${pin:-none})" >&2
  exit 1
fi
if [ -f "${sp}/pip/_vendor/bom.cdx.json" ]; then
  sed -i 's/pkg:pypi\/urllib3@2\.7\.0/pkg:pypi\/urllib3@2.8.0/g' "${sp}/pip/_vendor/bom.cdx.json"
  sed -i 's/"version": "2.7.0"/"version": "2.8.0"/' "${sp}/pip/_vendor/bom.cdx.json"
  sed -i -E 's/pkg:pypi\/certifi@[0-9.]+/pkg:pypi\/certifi@'"${CERTIFI_VER}"'/g' "${sp}/pip/_vendor/bom.cdx.json"
  sed -i 's/"version": "2026.6.17"/"version": "'"${CERTIFI_VER}"'"/' "${sp}/pip/_vendor/bom.cdx.json"
fi

# Runtime sidecar does not need pip; dropping it removes pip's vendored
# setuptools SBOM row (GHSA-XMJ3-9GF7-H52W) while urllib3/certifi stay pinned
# in site-packages.
"${VENV}/bin/python" -m pip uninstall -y pip

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
