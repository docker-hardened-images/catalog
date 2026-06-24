#!/bin/bash
set -euo pipefail

dockerize_args=("-timeout" "240s")
if [[ ${SKIP_KAFKA_CHECK:-false} != true ]]; then
  IFS=',' read -ra KAFKAS <<< "$KAFKA_BOOTSTRAP_SERVER"
  for i in "${KAFKAS[@]}"; do
    dockerize_args+=("-wait" "tcp://$i")
  done
fi
if [[ "${KAFKA_SCHEMAREGISTRY_URL:-}" && ${SKIP_SCHEMA_REGISTRY_CHECK:-false} != true ]]; then
  dockerize_args+=("-wait" "$KAFKA_SCHEMAREGISTRY_URL")
fi

# Do NOT fold JDK_JAVA_OPTIONS into JAVA_TOOL_OPTIONS: in -fips it is an @argfile,
# expanded for JDK_JAVA_OPTIONS but not JAVA_TOOL_OPTIONS ("Unrecognized option: @...").
JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-}${JAVA_OPTS:+ $JAVA_OPTS}${JMX_OPTS:+ $JMX_OPTS}"
if [[ ${ENABLE_OTEL:-false} == true ]]; then
  JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -javaagent:/datahub/datahub-mce-consumer/lib/opentelemetry-javaagent.jar"
fi
if [[ ${ENABLE_PROMETHEUS:-false} == true ]]; then
  JAVA_TOOL_OPTIONS="$JAVA_TOOL_OPTIONS -javaagent:/datahub/datahub-mce-consumer/lib/jmx_prometheus_javaagent.jar=4318:/datahub/datahub-mce-consumer/scripts/prometheus-config.yaml"
fi

export JAVA_TOOL_OPTIONS
exec dockerize "${dockerize_args[@]}" java -jar /datahub/datahub-mce-consumer/bin/mce-consumer-job.jar
