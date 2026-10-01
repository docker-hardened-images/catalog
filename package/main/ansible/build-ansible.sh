#!/bin/bash
# Ansible community-package venv staging, shared by the debian and alpine leaves.
# Installs the PyPI ansible distribution (curated collections plus
# ansible-core) at the final FHS path. cryptography is built from source
# against the system OpenSSL. Every other dependency is an exact pin in
# requirements.txt.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR            - work dir; holds requirements.txt
#   TARGET_DIR            - package root
#   PYTHON_BIN            - interpreter path (e.g. /usr/bin/python3.13)
#   ANSIBLE_VERSION       - community package version (e.g. 14.4.0)
#   ANSIBLE_CORE_VERSION  - ansible-core from build-data (e.g. 2.21.4)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"
: "${ANSIBLE_VERSION:?ANSIBLE_VERSION is required}"
: "${ANSIBLE_CORE_VERSION:?ANSIBLE_CORE_VERSION is required}"

VENV="${TARGET_DIR}/usr/lib/ansible"
mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"

export UV_PYTHON="${PYTHON_BIN}"
export UV_PYTHON_DOWNLOADS=never
export UV_COMPILE_BYTECODE="${UV_COMPILE_BYTECODE:-1}"
export UV_LINK_MODE=copy
# cryptography vendors OpenSSL unless this is set for the rust build.
export OPENSSL_NO_VENDOR=1
export OPENSSL_STATIC=0

# --no-deps so a later rebuild cannot float ansible-core or cryptography.
uv venv --python "${PYTHON_BIN}" "${VENV}"
uv pip install --python "${VENV}/bin/python" --no-deps \
  --no-binary cryptography \
  "ansible==${ANSIBLE_VERSION}" \
  "ansible-core==${ANSIBLE_CORE_VERSION}" \
  -r "${SOURCE_DIR}/requirements.txt"

# The rust extension must link the system libssl. A manylinux wheel has
# no NEEDED entry for libssl and would ignore the image OpenSSL module.
so=$(find "${VENV}" -path '*/cryptography/hazmat/bindings/_rust*.so' | head -n 1)
test -n "${so}"
# Capture readelf first. grep -q exits on the first hit and SIGPIPEs
# readelf, which set -o pipefail turns into a failed build.
readelf -d "${so}" > "${SOURCE_DIR}/cryptography-needed.txt"
grep -q 'libssl\.so' "${SOURCE_DIR}/cryptography-needed.txt"

# Collection unit/integration trees are named tests/. Do not delete a
# directory named test: Ansible test plugins live in plugins/test.
find "${VENV}" -depth -type d -name tests -exec rm -rf {} +
find "${VENV}" -depth -type d -name __pycache__ -exec rm -rf {} +
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete
# Collection dev manifests are not installed code. The package SBOM
# indexes them as Python packages, and the image scan then reports CVEs
# for versions this venv does not run.
find "${VENV}" -type f \( \
  -name 'Pipfile' -o -name 'Pipfile.lock' -o -name 'poetry.lock' \
  -o -name 'yarn.lock' -o -name 'package-lock.json' -o -name 'pnpm-lock.yaml' \
  -o -name 'antsibull-nox.toml' \
  -o -name '*requirements*.txt' -o -name '*requirements*.in' \
  -o -name 'constraints.txt' -o -name 'constraints-*.txt' \
  \) -delete
find "${VENV}" -depth -type d -name hacking -exec rm -rf {} +
rm -f "${VENV}/.lock"

for f in "${VENV}/bin"/* "${VENV}/pyvenv.cfg"; do
  [ -f "$f" ] || continue
  [ -L "$f" ] && continue
  sed -i "s|${TARGET_DIR}||g" "$f"
done

rc=0
for f in "${VENV}/bin"/* "${VENV}/pyvenv.cfg"; do
  [ -f "$f" ] || continue
  [ -L "$f" ] && continue
  while read -r line || [ -n "$line" ]; do
    case "$line" in
      *"${TARGET_DIR}"*)
        echo "staging path leaked into ${f}: ${line}" >&2
        rc=1
        ;;
    esac
  done < "$f"
done
test "$rc" -eq 0

# Relative links survive the buildpkg install root. ansible-test stays in
# the venv (it needs an upstream checkout to run) and is not on PATH.
cmds="ansible-community ansible ansible-playbook ansible-galaxy ansible-vault ansible-config ansible-doc ansible-inventory ansible-console ansible-pull"
for cmd in ${cmds}; do
  test -e "${VENV}/bin/${cmd}"
  ln -sfn "../lib/ansible/bin/${cmd}" "${TARGET_DIR}/usr/bin/${cmd}"
done
test -e "${VENV}/bin/ansible-test"

mkdir -p /opt/docker/sbom/ansible
chmod -R 0777 /opt/docker/sbom
