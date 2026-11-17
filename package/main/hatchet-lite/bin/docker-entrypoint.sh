#!/bin/bash
set -eo pipefail

CONFIG_DIR="${HATCHET_CONFIG_DIR:-/config}"

# Apply database schema migrations.
/usr/bin/hatchet-migrate

# On first start, generate config and seed credentials. Subsequent restarts
# are no-ops because --overwrite=false leaves existing files in place.
/usr/bin/hatchet-admin quickstart \
    --skip certs \
    --generated-config-dir "${CONFIG_DIR}" \
    --overwrite=false

# Hand off to the all-in-one server.
exec /usr/bin/hatchet-lite --config "${CONFIG_DIR}"
