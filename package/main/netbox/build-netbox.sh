#!/bin/bash
# Shared netbox app staging for the debian package leaf.
# Expects (exported by the definition pipeline — melange vars are not
# expanded inside this file):
#   SOURCE_DIR  - work dir containing netbox-src/, netbox-docker-src/,
#                 requirements-container.txt, overrides.txt
#   TARGET_DIR  - package root
#   PYTHON_BIN  - interpreter path (e.g. /usr/bin/python3.12)
set -eux -o pipefail

: "${SOURCE_DIR:?SOURCE_DIR is required}"
: "${TARGET_DIR:?TARGET_DIR is required}"
: "${PYTHON_BIN:?PYTHON_BIN is required}"

VENV="${TARGET_DIR}/usr/lib/netbox"
APP="${TARGET_DIR}/usr/share/netbox"

mkdir -p "${TARGET_DIR}/usr/lib" "${APP}"

cp -a "${SOURCE_DIR}/requirements-container.txt" "${APP}/requirements-container.txt"
cp -a "${SOURCE_DIR}/overrides.txt" "${APP}/overrides.txt"

export UV_NO_MANAGED_PYTHON=true
export UV_PYTHON_DOWNLOADS=never
export UV_PYTHON="${PYTHON_BIN}"

uv venv "${VENV}"
uv pip install --python "${VENV}/bin/python" \
  --override "${APP}/overrides.txt" \
  -r "${SOURCE_DIR}/netbox-src/requirements.txt" \
  -r "${APP}/requirements-container.txt"

mv "${SOURCE_DIR}/netbox-src/netbox" "${APP}/netbox"

cd "${SOURCE_DIR}/netbox-docker-src"
install -m 0755 docker/docker-entrypoint.sh "${APP}/docker-entrypoint.sh"
install -m 0755 docker/launch-netbox.sh "${APP}/launch-netbox.sh"
install -m 0644 docker/super_user.py "${APP}/super_user.py"
install -m 0644 docker/granian.py "${APP}/netbox/netbox/granian.py"
install -m 0644 docker/configuration.docker.py "${APP}/netbox/netbox/configuration.py"
install -m 0644 docker/ldap_config.docker.py "${APP}/netbox/netbox/ldap_config.py"
install -d -m 0755 /etc/netbox/config/ldap
install -d -m 0755 "${TARGET_DIR}/etc/netbox/config/ldap"
install -m 0644 -t /etc/netbox/config \
  configuration/configuration.py configuration/extra.py \
  configuration/logging.py configuration/plugins.py
install -m 0644 -t /etc/netbox/config/ldap \
  configuration/ldap/ldap_config.py configuration/ldap/extra.py
cp -a /etc/netbox/config/. "${TARGET_DIR}/etc/netbox/config/"

cd "${APP}/netbox"
export ALLOWED_HOSTS="*"
export DB_HOST="localhost"
export DB_NAME="netbox"
export DB_PASSWORD="netbox"
export DB_USER="netbox"
export DEBUG="true"
export PYTHONDONTWRITEBYTECODE="1"
export REDIS_CACHE_HOST="localhost"
export REDIS_HOST="localhost"
export SECRET_KEY="build-time-dummy-key-padded-to-fifty-plus-characters"
"${VENV}/bin/python" manage.py collectstatic --no-input

rm -f "${APP}/netbox/project-static/yarn.lock"
rm -f "${APP}/netbox/project-static/package.json"
rm -f "${APP}/netbox/project-static/netbox-graphiql/package.json"

find "${VENV}" \( -type d \( -name test -o -name tests -o -name __pycache__ \) -prune -exec rm -rf {} + \) || true
find "${VENV}" -type f \( -name '*.pyc' -o -name '*.pyo' \) -delete || true

for f in "${VENV}/bin"/*; do
  [ -f "$f" ] || continue
  read -r line < "$f" || true
  case "$line" in
    "#!${TARGET_DIR}"*) sed -i "1s|#!${TARGET_DIR}|#!|" "$f" ;;
  esac
done
