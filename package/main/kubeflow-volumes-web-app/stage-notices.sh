#!/bin/bash
# Stage the license files the venv's dist-info directories do not carry: the
# Rust crates linked into cryptography's _rust.abi3.so, and flask-cors, whose
# wheel ships no LICENSE.
# ${...} is not expanded here, so the definition must export:
#   SOURCE_DIR  - work dir with the inventory, cargo-home and flask-cors LICENSE
#   TARGET_DIR  - package root
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"

LICENSES="${TARGET_DIR}/usr/share/licenses/kubeflow-volumes-web-app"
REGISTRY="${SOURCE_DIR}/cargo-home/registry/src"
test -d "${REGISTRY}"

grep -E '^[a-z0-9_-]+ [0-9][^ ]* linked ' "${SOURCE_DIR}/cryptography-cargo-inventory.txt" \
  | awk '{ print $1, $2 }' > "${SOURCE_DIR}/linked-crates.txt"
test -s "${SOURCE_DIR}/linked-crates.txt"

while read -r name version; do
  src=$(find "${REGISTRY}" -mindepth 2 -maxdepth 2 -type d -name "${name}-${version}" | head -n 1)
  if [ -z "${src}" ]; then
    echo "crate ${name} ${version} was not fetched into ${REGISTRY}" >&2
    exit 1
  fi
  dest="${LICENSES}/cargo/${name}-${version}"
  mkdir -p "${dest}"
  find "${src}" -maxdepth 1 -type f \( -iname 'LICENSE*' -o -iname 'LICENCE*' -o -iname 'COPYING*' -o -iname 'NOTICE*' \) \
    -exec install -m 0644 -t "${dest}" {} +
  if [ -z "$(ls -A "${dest}")" ]; then
    echo "crate ${name} ${version} has no license file" >&2
    exit 1
  fi
done < "${SOURCE_DIR}/linked-crates.txt"

# The definition fetches this file from the flask-cors tag it names in the
# path. If the lock moves flask-cors, the lookup below fails until the URL and
# path move with it.
flask_cors=$(grep -oE '^flask-cors==[0-9.]+' "${SOURCE_DIR}/requirements-lock.txt")
flask_cors_version="${flask_cors#flask-cors==}"
install -D -m 0644 "${SOURCE_DIR}/flask-cors-${flask_cors_version}-LICENSE" \
  "${LICENSES}/python/flask-cors-${flask_cors_version}/LICENSE"
