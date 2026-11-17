#!/bin/bash
#
# Launches the storage-backend-specific jaeger-spark-dependencies job jar.
# JAR_PATH is set per image flavor (cassandra / elasticsearch7 / elasticsearch8 /
# elasticsearch9 / opensearch); the jar's manifest already carries the correct
# Main-Class for that backend, so no explicit class name is needed here.
set -euo pipefail

LOG4J_STATUS_LOGGER_LEVEL="${LOG4J_STATUS_LOGGER_LEVEL:-OFF}"

# Required for Spark to access internal JDK APIs on Java 21+ (JEP 396 strong
# encapsulation); matches upstream's own entrypoint.sh.
SPARK_JAVA_OPTS="--add-opens=java.base/java.lang=ALL-UNNAMED \
--add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
--add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
--add-opens=java.base/java.io=ALL-UNNAMED \
--add-opens=java.base/java.net=ALL-UNNAMED \
--add-opens=java.base/java.nio=ALL-UNNAMED \
--add-opens=java.base/java.util=ALL-UNNAMED \
--add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
--add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED \
--add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
--add-opens=java.base/sun.nio.cs=ALL-UNNAMED \
--add-opens=java.base/sun.security.action=ALL-UNNAMED \
--add-opens=java.base/sun.util.calendar=ALL-UNNAMED \
-Djdk.reflect.useDirectMethodHandle=false"

# shellcheck disable=SC2086
exec java ${SPARK_JAVA_OPTS} ${JAVA_OPTS:-} \
  -Dorg.apache.logging.log4j.simplelog.StatusLogger.level="${LOG4J_STATUS_LOGGER_LEVEL}" \
  -jar "${JAR_PATH}" "$@"
