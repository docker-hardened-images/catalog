#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e -o pipefail

SPARK_CLASSPATH="$SPARK_CLASSPATH:${SPARK_HOME}/jars/*"
for v in "${!SPARK_JAVA_OPT_@}"; do
    SPARK_EXECUTOR_JAVA_OPTS+=( "${!v}" )
done

if [ -n "$SPARK_EXTRA_CLASSPATH" ]; then
  SPARK_CLASSPATH="$SPARK_CLASSPATH:$SPARK_EXTRA_CLASSPATH"
fi

if [ -n "$HADOOP_CONF_DIR" ]; then
  SPARK_CLASSPATH="$HADOOP_CONF_DIR:$SPARK_CLASSPATH";
fi

if [ -n "$SPARK_CONF_DIR" ]; then
  SPARK_CLASSPATH="$SPARK_CONF_DIR:$SPARK_CLASSPATH";
else
  SPARK_CLASSPATH="${SPARK_HOME}/conf:$SPARK_CLASSPATH";
fi

# SPARK-43540: add current working directory into executor classpath
SPARK_CLASSPATH="$SPARK_CLASSPATH:$PWD"

# DHI: -Dspark.authenticate=${SPARK_AUTHENTICATE:-true}
export SPARK_LAUNCHER_OPTS="-Dspark.authenticate=${SPARK_AUTHENTICATE:-true}${SPARK_LAUNCHER_OPTS+ $SPARK_LAUNCHER_OPTS}"

case "$1" in
  driver)
    shift 1
    CMD=(
      "${SPARK_HOME}/bin/spark-submit"
      --conf "spark.driver.bindAddress=$SPARK_DRIVER_BIND_ADDRESS"
      --conf "spark.executorEnv.SPARK_DRIVER_POD_IP=$SPARK_DRIVER_BIND_ADDRESS"
      --deploy-mode client
      "$@"
    )

    # Execute the container CMD under tini for better hygiene
    exec /usr/bin/tini -s -- "${CMD[@]}"
    ;;
  executor)
    shift 1
    CMD=(
      "${JAVA_HOME}/bin/java"
      "${SPARK_EXECUTOR_JAVA_OPTS[@]}"
      -Xms"$SPARK_EXECUTOR_MEMORY"
      -Xmx"$SPARK_EXECUTOR_MEMORY"
      -cp "$SPARK_CLASSPATH:$SPARK_DIST_CLASSPATH"
      org.apache.spark.scheduler.cluster.k8s.KubernetesExecutorBackend
      --driver-url "$SPARK_DRIVER_URL"
      --executor-id "$SPARK_EXECUTOR_ID"
      --cores "$SPARK_EXECUTOR_CORES"
      --app-id "$SPARK_APPLICATION_ID"
      --hostname "$SPARK_EXECUTOR_POD_IP"
      --resourceProfileId "$SPARK_RESOURCE_PROFILE_ID"
      --podName "$SPARK_EXECUTOR_POD_NAME"
    )

    # Execute the container CMD under tini for better hygiene
    exec /usr/bin/tini -s -- "${CMD[@]}"
    ;;
  *)
    # Non-spark-on-k8s command provided, proceeding in pass-through mode...
    exec "$@"
    ;;
esac
