#!/bin/bash
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR required}"
: "${TARGET_DIR:?TARGET_DIR required}"
: "${UPSTREAM_DIR:?UPSTREAM_DIR required}"

lib_root="${TARGET_DIR}/usr/lib/jupyterhub-k8s-secret-sync"
venv="${lib_root}/.venv"

python3 -m venv --without-pip "${venv}"
pip3 --python "${venv}/bin/python3" install --no-cache-dir --require-hashes --no-deps \
  -r "${SOURCE_DIR}/requirements-lock.txt"

mkdir -p "${lib_root}/bin"
install -m 755 "${UPSTREAM_DIR}/images/secret-sync/acme-secret-sync.py" \
  "${lib_root}/bin/acme-secret-sync"
sed -i '1s|.*|#!/usr/lib/jupyterhub-k8s-secret-sync/.venv/bin/python3|' \
  "${lib_root}/bin/acme-secret-sync"

find "${venv}" \
  \( -type d \( -name test -o -name tests -o -name __pycache__ \) -prune -exec rm -rf {} + \)
find "${venv}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete

mkdir -p "${TARGET_DIR}/usr/bin"
ln -sf ../lib/jupyterhub-k8s-secret-sync/bin/acme-secret-sync \
  "${TARGET_DIR}/usr/bin/acme-secret-sync"
