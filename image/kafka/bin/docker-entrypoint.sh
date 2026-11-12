#!/usr/bin/env bash
set -e -o pipefail

export config="/opt/kafka/config/server.properties"

is_non_config_kafka_env() {
    case "$1" in
        KAFKA_CLUSTER_ID|KAFKA_DEBUG|KAFKA_GC_LOG_OPTS|KAFKA_HEAP_OPTS|KAFKA_JMX_HOSTNAME|KAFKA_JMX_OPTS|KAFKA_JMX_PORT|KAFKA_LOG4J_CMD_OPTS|KAFKA_LOG4J_LOGGERS|KAFKA_LOG4J_OPTS|KAFKA_LOG4J_ROOT_LOGLEVEL|KAFKA_OPTS|KAFKA_TOOLS_LOG4J_LOGLEVEL|KAFKA_VERSION|KAFKA_JVM_PERFORMANCE_OPTS)
            return 0
            ;;
    esac

    return 1
}

kafka_env_to_property() {
    local key="${1#KAFKA_}"

    key="${key//___/@HYPHEN@}"
    key="${key//__/@UNDERSCORE@}"
    key="${key//_/.}"
    key="${key//@HYPHEN@/-}"
    key="${key//@UNDERSCORE@/_}"

    printf '%s\n' "${key,,}"
}

set_kafka_property() {
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

process_kafka_environment() {
    if [ -z "${KAFKA_LISTENERS:-}" ] && [ -n "${KAFKA_ADVERTISED_LISTENERS:-}" ]; then
        export KAFKA_LISTENERS
        KAFKA_LISTENERS="$(printf '%s\n' "$KAFKA_ADVERTISED_LISTENERS" | sed -e 's|://[^:]*:|://0.0.0.0:|g')"
    fi

    while IFS='=' read -r name value; do
        if [[ "$name" != KAFKA_* ]] || is_non_config_kafka_env "$name"; then
            continue
        fi

        set_kafka_property "$(kafka_env_to_property "$name")" "$value"
    done < <(env)
}

process_kafka_environment

if [ -n "$(/opt/kafka/bin/kafka-storage.sh info -c "$config" | grep 'is not formatted')" ]; then
    if [ -z "${KAFKA_CLUSTER_ID}" ]; then
        export KAFKA_CLUSTER_ID="$(/opt/kafka/bin/kafka-storage.sh random-uuid | tail -n 1 )"
    fi

    /opt/kafka/bin/kafka-storage.sh format --no-initial-controllers --cluster-id "$KAFKA_CLUSTER_ID" --config "$config"
else
    echo "Logs folder not empty, skipping initialization"
fi

exec /opt/kafka/bin/kafka-server-start.sh "$config"
