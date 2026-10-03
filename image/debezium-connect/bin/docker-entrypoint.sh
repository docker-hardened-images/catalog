#!/usr/bin/env bash
set -e -o pipefail

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

# Point Kafka Connect at the connector plugins installed by the debezium
# connector packages. A CONNECT_PLUGIN_PATH override below wins if the caller
# sets one.
set_connect_property "plugin.path" "/usr/share/kafka/connect"

for required in CONNECT_BOOTSTRAP_SERVERS CONNECT_GROUP_ID CONNECT_CONFIG_STORAGE_TOPIC CONNECT_OFFSET_STORAGE_TOPIC; do
    if [ -z "${!required:-}" ]; then
        echo "${required} must be set" >&2
        exit 1
    fi
done

process_connect_environment

exec "${kafka_home}/bin/connect-distributed.sh" "$config"
