#!/usr/bin/env bash
set -euo pipefail

log4j_lib_dir="${1:?log4j lib directory is required}"

# Review upstream's bundled log4j-*.jar files on every Flink bump before updating this replacement set.
rm -f "${log4j_lib_dir}/log4j-"*.jar

for module in \
  log4j-1.2-api \
  log4j-api \
  log4j-core \
  log4j-layout-template-json \
  log4j-slf4j-impl
do
  install -m 0644 "${SOURCE_DIR}/${module}-${LOG4J_VERSION}.jar" "${log4j_lib_dir}/"
done
