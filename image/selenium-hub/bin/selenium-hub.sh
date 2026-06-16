#!/usr/bin/bash
#
# SPDX-License-Identifier: Apache-2.0
# Derived from SeleniumHQ/docker-selenium Hub/start-selenium-grid-hub.sh
# (Copyright Software Freedom Conservancy, licensed Apache-2.0). Modifications
# Copyright Docker, Inc.
#
# Port of upstream docker-selenium Hub/start-selenium-grid-hub.sh. Drops Python
# supervisord (JVM runs as PID 1) and the Go metrics exporter (port 9615); SE_*
# vars map to the same hub flags/JVM opts. Trace export needs the OTLP jars via
# SE_EXTRA_LIBS — the prefetched /external_jars are not bundled.

set -eu -o pipefail

SELENIUM_SERVER_JAR=${SELENIUM_SERVER_JAR:-/opt/selenium/selenium-server.jar}
SE_OPTS="${SE_OPTS:-}"
SE_JAVA_OPTS="${SE_JAVA_OPTS:-}"

# A flag already present in user SE_OPTS wins; don't append it twice.
append_se_opts() { # append_se_opts <flag> [value]
  local option="${1}" value="${2:-}"
  if [[ "${SE_OPTS}" == *"${option}"* ]]; then
    return
  fi
  SE_OPTS="${SE_OPTS} ${option}"
  if [ -n "${value}" ]; then
    SE_OPTS="${SE_OPTS} ${value}"
  fi
}

[ -n "${SE_HUB_HOST:-}" ] && append_se_opts --host "${SE_HUB_HOST}"
[ -n "${SE_HUB_PORT:-}" ] && append_se_opts --port "${SE_HUB_PORT}"
[ -n "${SE_SUB_PATH:-}" ] && append_se_opts --sub-path "${SE_SUB_PATH}"
[ -n "${SE_LOG_LEVEL:-}" ] && append_se_opts --log-level "${SE_LOG_LEVEL}"
[ -n "${SE_HTTP_LOGS:-}" ] && append_se_opts --http-logs "${SE_HTTP_LOGS}"
[ -n "${SE_STRUCTURED_LOGS:-}" ] && append_se_opts --structured-logs "${SE_STRUCTURED_LOGS}"
[ -n "${SE_PLAIN_LOGS:-}" ] && append_se_opts --plain-logs "${SE_PLAIN_LOGS}"
[ -n "${SE_EXTERNAL_URL:-}" ] && append_se_opts --external-url "${SE_EXTERNAL_URL}"

if [ "${SE_ENABLE_TLS:-false}" = "true" ]; then
  if [ -n "${SE_JAVA_SSL_TRUST_STORE:-}" ]; then
    SE_JAVA_OPTS="${SE_JAVA_OPTS} -Djavax.net.ssl.trustStore=${SE_JAVA_SSL_TRUST_STORE}"
  fi
  # password env may be a file path or a literal
  if [ -f "${SE_JAVA_SSL_TRUST_STORE_PASSWORD:-}" ]; then
    SE_JAVA_SSL_TRUST_STORE_PASSWORD="$(cat "${SE_JAVA_SSL_TRUST_STORE_PASSWORD}")"
  fi
  if [ -n "${SE_JAVA_SSL_TRUST_STORE_PASSWORD:-}" ]; then
    SE_JAVA_OPTS="${SE_JAVA_OPTS} -Djavax.net.ssl.trustStorePassword=${SE_JAVA_SSL_TRUST_STORE_PASSWORD}"
  fi
  SE_JAVA_OPTS="${SE_JAVA_OPTS} -Djdk.internal.httpclient.disableHostnameVerification=${SE_JAVA_DISABLE_HOSTNAME_VERIFICATION:-true}"
  [ -n "${SE_HTTPS_CERTIFICATE:-}" ] && append_se_opts --https-certificate "${SE_HTTPS_CERTIFICATE}"
  [ -n "${SE_HTTPS_PRIVATE_KEY:-}" ] && append_se_opts --https-private-key "${SE_HTTPS_PRIVATE_KEY}"
fi

[ -n "${SE_REGISTRATION_SECRET:-}" ] && append_se_opts --registration-secret "${SE_REGISTRATION_SECRET}"
[ -n "${SE_DISABLE_UI:-}" ] && append_se_opts --disable-ui "${SE_DISABLE_UI}"
[ -n "${SE_ROUTER_USERNAME:-}" ] && append_se_opts --username "${SE_ROUTER_USERNAME}"
[ -n "${SE_ROUTER_PASSWORD:-}" ] && append_se_opts --password "${SE_ROUTER_PASSWORD}"
[ -n "${SE_REJECT_UNSUPPORTED_CAPS:-}" ] && append_se_opts --reject-unsupported-caps "${SE_REJECT_UNSUPPORTED_CAPS}"
[ -n "${SE_DISTRIBUTOR_SLOT_SELECTOR:-}" ] && append_se_opts --slot-selector "${SE_DISTRIBUTOR_SLOT_SELECTOR}"
[ -n "${SE_NEW_SESSION_THREAD_POOL_SIZE:-}" ] && append_se_opts --newsession-threadpool-size "${SE_NEW_SESSION_THREAD_POOL_SIZE}"
[ -n "${SE_SESSION_REQUEST_TIMEOUT:-}" ] && append_se_opts --session-request-timeout "${SE_SESSION_REQUEST_TIMEOUT}"
[ -n "${SE_SESSION_RETRY_INTERVAL:-}" ] && append_se_opts --session-retry-interval "${SE_SESSION_RETRY_INTERVAL}"
[ -n "${SE_HEALTHCHECK_INTERVAL:-}" ] && append_se_opts --healthcheck-interval "${SE_HEALTHCHECK_INTERVAL}"
[ -n "${SE_RELAX_CHECKS:-}" ] && append_se_opts --relax-checks "${SE_RELAX_CHECKS}"
[ -n "${SE_BIND_HOST:-}" ] && append_se_opts --bind-host "${SE_BIND_HOST}"
[ -n "${SE_EVENT_BUS_HEARTBEAT_PERIOD:-}" ] && append_se_opts --eventbus-heartbeat-period "${SE_EVENT_BUS_HEARTBEAT_PERIOD}"
[ -n "${SE_TCP_TUNNEL:-}" ] && append_se_opts --tcp-tunnel "${SE_TCP_TUNNEL}"
if [ -n "${CONFIG_FILE:-}" ] && [ -f "${CONFIG_FILE}" ]; then
  append_se_opts --config "${CONFIG_FILE}"
fi

EXTRA_LIBS=""
[ -n "${SE_EXTRA_LIBS:-}" ] && EXTRA_LIBS="--ext ${SE_EXTRA_LIBS}"

# Only enable tracing when an OTLP endpoint is set (upstream's gate).
if [ "${SE_ENABLE_TRACING:-false}" = "true" ] && [ -n "${SE_OTEL_EXPORTER_ENDPOINT:-}" ]; then
  if [ -f /external_jars/.classpath.txt ]; then
    EXTERNAL_JARS="$(cat /external_jars/.classpath.txt)"
    if [ -n "${EXTRA_LIBS}" ]; then
      EXTRA_LIBS="${EXTRA_LIBS}:${EXTERNAL_JARS}"
    else
      EXTRA_LIBS="--ext ${EXTERNAL_JARS}"
    fi
  fi
  [ -n "${SE_OTEL_SERVICE_NAME:-}" ] && SE_JAVA_OPTS="${SE_JAVA_OPTS} -Dotel.resource.attributes=service.name=${SE_OTEL_SERVICE_NAME}${SE_OTEL_RESOURCE_ATTRIBUTES:+,${SE_OTEL_RESOURCE_ATTRIBUTES}}"
  [ -n "${SE_OTEL_TRACES_EXPORTER:-}" ] && SE_JAVA_OPTS="${SE_JAVA_OPTS} -Dotel.traces.exporter=${SE_OTEL_TRACES_EXPORTER}"
  SE_JAVA_OPTS="${SE_JAVA_OPTS} -Dotel.exporter.otlp.endpoint=${SE_OTEL_EXPORTER_ENDPOINT}"
  [ -n "${SE_OTEL_JAVA_GLOBAL_AUTOCONFIGURE_ENABLED:-}" ] && SE_JAVA_OPTS="${SE_JAVA_OPTS} -Dotel.java.global-autoconfigure.enabled=${SE_OTEL_JAVA_GLOBAL_AUTOCONFIGURE_ENABLED}"
else
  append_se_opts --tracing false
  SE_JAVA_OPTS="${SE_JAVA_OPTS} -Dwebdriver.remote.enableTracing=false"
fi

[ -n "${SE_JAVA_HTTPCLIENT_VERSION:-}" ] && SE_JAVA_OPTS="${SE_JAVA_OPTS} -Dwebdriver.httpclient.version=${SE_JAVA_HTTPCLIENT_VERSION}"

if [ "${SE_JAVA_HEAP_DUMP:-false}" = "true" ]; then
  SE_JAVA_OPTS="${SE_JAVA_OPTS} -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/opt/selenium/logs"
fi

[ -n "${SE_JAVA_OPTS_DEFAULT:-}" ] && SE_JAVA_OPTS="${SE_JAVA_OPTS_DEFAULT} ${SE_JAVA_OPTS}"
[ -n "${JAVA_OPTS:-}" ] && SE_JAVA_OPTS="${SE_JAVA_OPTS} ${JAVA_OPTS}"

echo "Starting Selenium Grid Hub with JAVA_OPTS: ${SE_JAVA_OPTS}"

# shellcheck disable=SC2086 # flag strings are meant to word-split
exec java ${SE_JAVA_OPTS} -jar "${SELENIUM_SERVER_JAR}" ${EXTRA_LIBS} hub ${SE_OPTS} "$@"
