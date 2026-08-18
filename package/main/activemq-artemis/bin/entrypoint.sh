#!/usr/bin/env bash

set -eu -o pipefail

# === Configuration Paths ===
BROKER_HOME=/opt/activemq-artemis/broker
CONFIG_PATH=$BROKER_HOME/etc
export BROKER_HOME CONFIG_PATH

# === Ensure required env vars are set ===
ARTEMIS_USER="${ARTEMIS_USER:?ARTEMIS_USER must be set}"
ARTEMIS_PASSWORD="${ARTEMIS_PASSWORD:?ARTEMIS_PASSWORD must be set}"

# === Handle anonymous login option ===
if [ "${ANONYMOUS_LOGIN:-false}" = "true" ]; then
  LOGIN_OPTION="--allow-anonymous"
else
  LOGIN_OPTION="--require-login"
fi

# === Only create broker if not already created ===
if [ ! -f "$CONFIG_PATH/broker.xml" ]; then
    IFS=" " read -r -a EXTRA_ARGS <<< "${EXTRA_ARGS:-}"
    CREATE_ARGUMENTS=(--user "${ARTEMIS_USER}" --password "${ARTEMIS_PASSWORD}" --silent "${LOGIN_OPTION}" "${EXTRA_ARGS[@]}")

    /opt/activemq-artemis/bin/artemis create "${CREATE_ARGUMENTS[@]}" "$BROKER_HOME"

    # Copy override configs if available
    if [ -d "$BROKER_HOME/etc-override" ]; then
        for file in "$BROKER_HOME/etc-override/"*; do
            [ -f "$file" ] && echo "copying override file: $(basename "$file")" && cp "$file" "$CONFIG_PATH" || :
        done
    fi
else
    echo "skipping broker instance creation; instance already exists"
fi

# === Start broker ===
exec "$BROKER_HOME/bin/artemis" "$@"
