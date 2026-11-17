#!/usr/bin/bash
#
# Port of upstream docker-selenium NodeBase/start-selenium-node.sh and
# NodeChromium wiring.

set -eu -o pipefail

SELENIUM_SERVER_JAR=${SELENIUM_SERVER_JAR:-/opt/selenium/selenium-server.jar}
SE_OPTS_USER="${SE_OPTS:-}"
SE_JAVA_OPTS="${SE_JAVA_OPTS:-}"

SE_ARGS=()

# append_se_opts <flag> [value...]: skip if the user already set <flag> in SE_OPTS.
append_se_opts() {
  local option="${1}"
  if [[ "${SE_OPTS_USER}" == *"${option}"* ]]; then
    return
  fi
  SE_ARGS+=("${option}")
  shift
  local value
  for value in "$@"; do
    SE_ARGS+=("${value}")
  done
}

[ -n "${SE_NODE_GRID_URL:-}" ] && append_se_opts --grid-url "${SE_NODE_GRID_URL}"
if [ -z "${SE_NODE_GRID_URL:-}" ] && [ -n "${SE_HUB_HOST:-}" ]; then
  hub_scheme="http"
  [ "${SE_ENABLE_TLS:-false}" = "true" ] && hub_scheme="https"
  append_se_opts --grid-url "${hub_scheme}://${SE_HUB_HOST}:${SE_HUB_PORT:-4444}"
fi

[ -n "${SE_EVENT_BUS_HOST:-}" ] && append_se_opts --publish-events "tcp://${SE_EVENT_BUS_HOST}:${SE_EVENT_BUS_PUBLISH_PORT:-4442}"
[ -n "${SE_EVENT_BUS_HOST:-}" ] && append_se_opts --subscribe-events "tcp://${SE_EVENT_BUS_HOST}:${SE_EVENT_BUS_SUBSCRIBE_PORT:-4443}"

[ -n "${SE_NODE_HOST:-}" ] && append_se_opts --host "${SE_NODE_HOST}"
[ -n "${SE_NODE_PORT:-}" ] && append_se_opts --port "${SE_NODE_PORT}"
[ -n "${SE_LOG_LEVEL:-}" ] && append_se_opts --log-level "${SE_LOG_LEVEL}"
[ -n "${SE_HTTP_LOGS:-}" ] && append_se_opts --http-logs "${SE_HTTP_LOGS}"
[ -n "${SE_STRUCTURED_LOGS:-}" ] && append_se_opts --structured-logs "${SE_STRUCTURED_LOGS}"
[ -n "${SE_PLAIN_LOGS:-}" ] && append_se_opts --plain-logs "${SE_PLAIN_LOGS}"

[ -n "${SE_NODE_MAX_SESSIONS:-}" ] && append_se_opts --max-sessions "${SE_NODE_MAX_SESSIONS}"
[ -n "${SE_NODE_SESSION_TIMEOUT:-}" ] && append_se_opts --session-timeout "${SE_NODE_SESSION_TIMEOUT}"
[ -n "${SE_NODE_REGISTER_PERIOD:-}" ] && append_se_opts --register-period "${SE_NODE_REGISTER_PERIOD}"
[ -n "${SE_NODE_REGISTER_CYCLE:-}" ] && append_se_opts --register-cycle "${SE_NODE_REGISTER_CYCLE}"
# Drain count: the DHI SE_NODE_ name wins, then upstream's precedence order —
# legacy bare DRAIN_AFTER_SESSION_COUNT, then SE_DRAIN_AFTER_SESSION_COUNT
# (baked default "0" = disabled).
DRAIN_COUNT="${SE_NODE_DRAIN_AFTER_SESSION_COUNT:-${DRAIN_AFTER_SESSION_COUNT:-${SE_DRAIN_AFTER_SESSION_COUNT:-}}}"
[ -n "${DRAIN_COUNT}" ] && append_se_opts --drain-after-session-count "${DRAIN_COUNT}"
[ -n "${SE_NODE_DETECT_DRIVERS:-}" ] && append_se_opts --detect-drivers "${SE_NODE_DETECT_DRIVERS}"
[ -n "${SE_NODE_ENABLE_MANAGED_DOWNLOADS:-}" ] && append_se_opts --enable-managed-downloads "${SE_NODE_ENABLE_MANAGED_DOWNLOADS}"
[ -n "${SE_NODE_ENABLE_CDP:-}" ] && append_se_opts --enable-cdp "${SE_NODE_ENABLE_CDP}"

# webdriver-executable pins the bundled chromedriver: detect-drivers would
# otherwise resolve it via SeleniumManager, which needs network the node lacks.
NODE_CONFIG_BROWSER_VERSION="${SE_NODE_BROWSER_VERSION:-stable}"
NODE_CONFIG_STEREOTYPE='{"browserName": "chrome", "browserVersion": "'"${NODE_CONFIG_BROWSER_VERSION}"'", "platformName": "Linux"}'
append_se_opts --driver-configuration "display-name=chromium" "webdriver-executable=/usr/bin/chromedriver" "max-sessions=${SE_NODE_MAX_SESSIONS:-1}" "stereotype=${NODE_CONFIG_STEREOTYPE}"

if [ "${SE_ENABLE_TLS:-false}" = "true" ]; then
  if [ -n "${SE_JAVA_SSL_TRUST_STORE:-}" ]; then
    SE_JAVA_OPTS="${SE_JAVA_OPTS} -Djavax.net.ssl.trustStore=${SE_JAVA_SSL_TRUST_STORE}"
  fi
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
[ -n "${SE_BIND_HOST:-}" ] && append_se_opts --bind-host "${SE_BIND_HOST}"
if [ -n "${CONFIG_FILE:-}" ] && [ -f "${CONFIG_FILE}" ]; then
  append_se_opts --config "${CONFIG_FILE}"
fi

EXTRA_LIBS=""
[ -n "${SE_EXTRA_LIBS:-}" ] && EXTRA_LIBS="--ext ${SE_EXTRA_LIBS}"

# The OTLP jars are not bundled (/external_jars is absent); trace export needs
# them supplied via SE_EXTRA_LIBS.
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

echo "Starting Selenium Grid Node with JAVA_OPTS: ${SE_JAVA_OPTS}"

# tini reaps orphaned Chromium subprocesses; the JVM does not reap grandchildren.
# SE_JAVA_OPTS, EXTRA_LIBS and SE_OPTS_USER are intentionally word-split.
# shellcheck disable=SC2086
exec /usr/bin/tini -- java ${SE_JAVA_OPTS} -jar "${SELENIUM_SERVER_JAR}" ${EXTRA_LIBS} node "${SE_ARGS[@]}" ${SE_OPTS_USER} "$@"
