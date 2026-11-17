#!/bin/bash

set -e

# Based on gitlab-base/scripts/entrypoint.sh from the gitlab-org/build/CNG
# repository, with the parts this image does not need removed:
#
#   * the Red Hat check is gone, because this image is built on Debian
#   * /scripts/exec-env is gone, because it only re-exports variables that the
#     gomplate tool would have written, and this image does not use gomplate
#   * set-config fills in templates with erb instead of gomplate

/scripts/set-config "${CONFIG_TEMPLATE_DIRECTORY}" "${CONFIG_DIRECTORY:=$CONFIG_TEMPLATE_DIRECTORY}"

if [ -f /etc/system-fips ]; then
  export FIPS_MODE=${FIPS_MODE-1}
  export OPENSSL_FORCE_FIPS_MODE=${OPENSSL_FORCE_FIPS_MODE-1}
fi

if [ "${USE_TINI-1}" -eq 1 ]; then
  INIT_CMD="/usr/bin/tini --"
fi

exec ${INIT_CMD} "$@"
