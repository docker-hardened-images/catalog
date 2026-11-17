#!/bin/bash

set -e

"$(dirname "$0")/set-config" "${CONFIG_TEMPLATE_DIRECTORY}" "${CONFIG_DIRECTORY:=$CONFIG_TEMPLATE_DIRECTORY}"

exec "$@"
