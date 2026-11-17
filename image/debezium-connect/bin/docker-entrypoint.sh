#!/usr/bin/env bash
set -e -o pipefail

# Same invocation contract as the upstream debezium/connect image: `start`
# runs the Connect distributed worker, and any other command is executed as
# given. The image's default command is `start`.
if [ "${1:-start}" != "start" ]; then
    exec "$@"
fi

kafka_home="/usr/share/kafka"
runtime_dir="/var/lib/kafka-connect"
config="${runtime_dir}/connect-distributed.properties"

# Kafka comes from the read-only dhi/pkg-kafka tree, so its stock config is
# copied into a writable runtime dir before the CONNECT_* overrides are applied.
# Nothing under /usr/share is modified at runtime.
mkdir -p "${runtime_dir}/logs"
cp "${kafka_home}/config/connect-distributed.properties" "$config"

# Kafka's bin scripts default the log dir to ${kafka_home}/logs, which is
# read-only here; point it at the writable runtime dir.
export LOG_DIR="${runtime_dir}/logs"

connect_env_to_property() {
    local key="${1#CONNECT_}"

    key="${key//___/@HYPHEN@}"
    key="${key//__/@UNDERSCORE@}"
    key="${key//_/.}"
    key="${key//@HYPHEN@/-}"
    key="${key//@UNDERSCORE@/_}"

    printf '%s\n' "${key,,}"
}

set_connect_property() {
    local property="$1"
    local value="$2"
    local escaped_property
    local escaped_value

    escaped_property="$(printf '%s\n' "$property" | sed 's/[][\/.^$*]/\\&/g')"
    escaped_value="$(printf '%s\n' "$value" | sed 's/[\/&\\]/\\&/g')"

    if grep -q "^${escaped_property}[[:space:]]*=" "$config"; then
        sed -i "s/^${escaped_property}[[:space:]]*=.*/${property}=${escaped_value}/" "$config"
    else
        printf '%s=%s\n' "$property" "$value" >> "$config"
    fi
}

process_connect_environment() {
    while IFS='=' read -r name value; do
        if [[ "$name" != CONNECT_* ]]; then
            continue
        fi

        set_connect_property "$(connect_env_to_property "$name")" "$value"
    done < <(env)
}

# The upstream image reads these unprefixed names (and defaults the first
# few). Map each one onto its CONNECT_* or KAFKA_* setting before validation.
# An explicit CONNECT_* (or KAFKA_*) value always takes precedence.
alias_connect_setting() {
    local target="$1"
    local alias_name="$2"
    local default_value="${3:-}"
    local value="${!target:-}"

    if [ -z "$value" ]; then
        value="${!alias_name:-$default_value}"
    fi
    if [ -n "$value" ]; then
        export "${target}=${value}"
    fi
}

alias_connect_setting CONNECT_BOOTSTRAP_SERVERS BOOTSTRAP_SERVERS "0.0.0.0:9092"
alias_connect_setting CONNECT_GROUP_ID GROUP_ID "1"
alias_connect_setting CONNECT_CONFIG_STORAGE_TOPIC CONFIG_STORAGE_TOPIC
alias_connect_setting CONNECT_OFFSET_STORAGE_TOPIC OFFSET_STORAGE_TOPIC
alias_connect_setting CONNECT_REST_PORT REST_PORT "8083"
alias_connect_setting CONNECT_KEY_CONVERTER KEY_CONVERTER "org.apache.kafka.connect.json.JsonConverter"
alias_connect_setting CONNECT_VALUE_CONVERTER VALUE_CONVERTER "org.apache.kafka.connect.json.JsonConverter"
alias_connect_setting KAFKA_HEAP_OPTS HEAP_OPTS

# Point Kafka Connect at the connector plugins installed by the debezium
# connector packages. A CONNECT_PLUGIN_PATH override below wins if the caller
# sets one.
set_connect_property "plugin.path" "/usr/share/kafka/connect"

# Bootstrap servers and group id have defaults (as upstream does); the storage
# topics have none, so the worker refuses to start without them.
if [ -z "${CONNECT_CONFIG_STORAGE_TOPIC:-}" ]; then
    echo "CONNECT_CONFIG_STORAGE_TOPIC (or CONFIG_STORAGE_TOPIC) must be set" >&2
    exit 1
fi
if [ -z "${CONNECT_OFFSET_STORAGE_TOPIC:-}" ]; then
    echo "CONNECT_OFFSET_STORAGE_TOPIC (or OFFSET_STORAGE_TOPIC) must be set" >&2
    exit 1
fi

process_connect_environment

exec "${kafka_home}/bin/connect-distributed.sh" "$config"
