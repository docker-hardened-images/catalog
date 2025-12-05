#!/bin/bash
set -e -o pipefail

export config="/opt/kafka/config/server.properties"
result="$(/opt/kafka/kafka.Kafka setup \
    --default-configs-dir /etc/kafka/config \
    --mounted-configs-dir /etc/kafka/config \
    --final-configs-dir /opt/kafka/config 2>&1)"  || \
      [[ "$result" == *"already formatted"* ]] || \
      { echo $result && (exit 1) }

exec /opt/kafka/kafka.Kafka start --config $config $KAFKA_LOG4J_CMD_OPTS
