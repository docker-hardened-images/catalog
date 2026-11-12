#!/bin/bash
#
# Derived from GitLab CNG, MIT licensed:
# https://gitlab.com/gitlab-org/build/CNG/-/blob/master/gitlab-base/scripts/entrypoint.sh
# DHI ships no tini, so the command is exec'd directly.

set -e

/scripts/set-config "${CONFIG_TEMPLATE_DIRECTORY}" "${CONFIG_DIRECTORY:=$CONFIG_TEMPLATE_DIRECTORY}"

exec /scripts/exec-env "$@"
