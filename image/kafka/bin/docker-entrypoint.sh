#!/usr/bin/env bash
set -e -o pipefail

export config="/opt/kafka/config/server.properties"
if [ -n "$(/opt/kafka/bin/kafka-storage.sh info -c "$config" | grep 'is not formatted')" ]; then
    if [ -z "${KAFKA_CLUSTER_ID}" ]; then
        export KAFKA_CLUSTER_ID="$(/opt/kafka/bin/kafka-storage.sh random-uuid | tail -n 1 )"
    fi

    /opt/kafka/bin/kafka-storage.sh format --no-initial-controllers --cluster-id "$KAFKA_CLUSTER_ID" --config "$config"
else
    echo "Logs folder not empty, skipping initialization"
fi

exec /opt/kafka/bin/kafka-server-start.sh "$config"
