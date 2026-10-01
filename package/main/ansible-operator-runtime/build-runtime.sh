#!/bin/bash
# Builds the ansible-operator Python runtime venv at its final path from the
# Pipfile.lock upstream ships in images/ansible-operator, then stages it.
# Expects SOURCE_DIR, TARGET_DIR and PYTHON_BIN from the definition pipeline.
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

VENV=/usr/lib/ansible-operator-runtime
IMAGE_SRC="${SOURCE_DIR}/ansible-operator-plugins/images/ansible-operator"
REQ="${SOURCE_DIR}/requirements.txt"

jq -r '.default | to_entries[] | select(.key != "cryptography") | "\(.key)\(.value.version) \(.value.hashes | map("--hash=" + .) | join(" "))"' \
  "${IMAGE_SRC}/Pipfile.lock" > "${REQ}"
grep -c '^ansible-core==' "${REQ}"

"${PYTHON_BIN}" -m venv "${VENV}"
"${VENV}/bin/python3" -m pip --version

"${VENV}/bin/python3" -m pip install --no-cache-dir --require-hashes --no-deps -r "${REQ}"
# GHSA-g6cj-pr64-35w5: the lock pins cryptography 49.0.0
"${VENV}/bin/python3" -m pip install --no-cache-dir --no-binary cryptography "cryptography==50.0.1"
# CVE-2026-59884, CVE-2026-59885, CVE-2026-59886: the lock pins pyasn1 0.6.3
"${VENV}/bin/python3" -m pip install --no-cache-dir --no-deps "pyasn1==0.6.4"
# CVE-2026-97687, CVE-2026-97688, CVE-2026-97689: the lock pins urllib3 2.7.0
"${VENV}/bin/python3" -m pip install --no-cache-dir --no-deps "urllib3==2.8.0"
# CVE-2026-49264, CVE-2026-49265: the lock pins oauthlib 3.3.1
"${VENV}/bin/python3" -m pip install --no-cache-dir --no-deps "oauthlib==4.0.0"
"${VENV}/bin/python3" -m pip install --no-cache-dir --no-deps "${IMAGE_SRC}/ansible_runner_http"

"${VENV}/bin/python3" -m pip uninstall -y pip setuptools wheel
sp="$(echo "${VENV}"/lib/python*/site-packages)"
rm -rf "${sp}"/pip "${sp}"/pip-*.dist-info \
  "${sp}"/setuptools "${sp}"/setuptools-*.dist-info "${sp}"/pkg_resources \
  "${sp}"/_distutils_hack "${sp}"/distutils-precedence.pth \
  "${sp}"/wheel "${sp}"/wheel-*.dist-info \
  "${sp}"/ansible_test "${VENV}/bin/ansible-test"
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete
find "${VENV}" -depth -type d -name __pycache__ -exec rm -rf '{}' +

for f in "${VENV}/bin"/*; do
  case "${f##*/}" in
    ansible | ansible-config | ansible-console | ansible-doc | ansible-galaxy | ansible-inventory | ansible-playbook | ansible-pull | ansible-vault | ansible-runner) ;;
    python | python3 | python3.* | activate) ;;
    *) rm -f "${f}" ;;
  esac
done

export PATH="${VENV}/bin:${PATH}" LANG=C.UTF-8 LC_ALL=C.UTF-8
ansible --version | grep -F 'ansible [core '
ansible-runner --version
ansible-galaxy --version | grep -F 'ansible-galaxy [core '
python3 -c 'import ansible_runner, ansible_runner_http, kubernetes, cryptography, yaml, jinja2, requests_unixsocket'
python3 -c 'from cryptography.hazmat.backends.openssl.backend import backend; print(backend.openssl_version_text())' | grep -F 'OpenSSL 3.'
rust_so="$(echo "${sp}"/cryptography/hazmat/bindings/_rust.*.so)"
grep -q 'libssl.so.3' "${rust_so}"
grep -q 'libcrypto.so.3' "${rust_so}"
python3 -c 'from importlib.metadata import entry_points; assert [e for e in entry_points(group="ansible_runner.plugins") if e.name == "http"]'
ANSIBLE_LOCAL_TEMP=/tmp/ansible-smoke ANSIBLE_REMOTE_TMP=/tmp/ansible-smoke \
  ansible -i localhost, -c local -m ping all | grep -F '"ping": "pong"'

mkdir -p "${TARGET_DIR}/usr/lib" "${TARGET_DIR}/usr/bin"
cp -a "${VENV}" "${TARGET_DIR}/usr/lib/"
for f in ansible ansible-config ansible-console ansible-doc ansible-galaxy ansible-inventory ansible-playbook ansible-pull ansible-vault ansible-runner; do
  ln -sf "../lib/ansible-operator-runtime/bin/${f}" "${TARGET_DIR}/usr/bin/${f}"
done
head -1 "${TARGET_DIR}${VENV}/bin/ansible" | grep -qx "#!${VENV}/bin/python3"
