#!/bin/bash
# Post-install jar remediation for Spark package CVEs.
#
# Maven dependencyManagement pins do not reach shaded copies inside
# hadoop-client-runtime and parquet-jackson, and Spark's Hive 2.3.x
# line cannot be upgraded at build time without breaking the upstream
# Hive profile. This script replaces vulnerable loose jars and repacks
# shaded dependencies after make-distribution.
set -euo pipefail

JARS_DIR="${1:?usage: remediate-jars.sh <jars-dir> <patch-deps-dir> <jackson-version>}"
PATCH_DIR="${2:?usage: remediate-jars.sh <jars-dir> <patch-deps-dir> <jackson-version>}"
JACKSON_VERSION="${3:?usage: remediate-jars.sh <jars-dir> <patch-deps-dir> <jackson-version>}"

JACKSON_CORE="${PATCH_DIR}/jackson-core-${JACKSON_VERSION}.jar"
JACKSON_DATABIND="${PATCH_DIR}/jackson-databind-${JACKSON_VERSION}.jar"
JACKSON_ANNOTATIONS="${PATCH_DIR}/jackson-annotations-${JACKSON_VERSION}.jar"
COMMONS_CONFIGURATION2="${PATCH_DIR}/commons-configuration2-2.15.0.jar"
JLINE_REMOTE_TELNET="${PATCH_DIR}/jline-remote-telnet-4.2.1.jar"
DERBY="${PATCH_DIR}/derby-10.17.1.0.jar"
DERBYSHARED="${PATCH_DIR}/derbyshared-10.17.1.0.jar"
DERBYTOOLS="${PATCH_DIR}/derbytools-10.17.1.0.jar"
LIBTHRIFT="${PATCH_DIR}/libthrift-0.23.0.jar"
HIVE_JDBC_313="${PATCH_DIR}/hive-jdbc-3.1.3.jar"

for jar in \
    "$JACKSON_CORE" "$JACKSON_DATABIND" "$JACKSON_ANNOTATIONS" \
    "$COMMONS_CONFIGURATION2" "$JLINE_REMOTE_TELNET" \
    "$DERBY" "$DERBYSHARED" "$DERBYTOOLS" "$LIBTHRIFT" \
    "$HIVE_JDBC_313"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

relocate_tree() {
    local workdir="$1"
    local srcjar="$2"
    local srcsub="$3"
    local destsub="$4"
    local tmp
    tmp="$(mktemp -d)"

    (cd "$tmp" && jar xf "$srcjar")

    rm -rf "${workdir}/${destsub}"
    find "${workdir}/META-INF/versions" -type d -path "*/${destsub}" -prune -exec rm -rf {} + 2>/dev/null || true

    mkdir -p "${workdir}/$(dirname "$destsub")"
    cp -a "$tmp/$srcsub" "${workdir}/${destsub}"

    for verpath in "$tmp"/META-INF/versions/*/; do
        [ -d "$verpath" ] || continue
        ver="$(basename "$verpath")"
        if [ -d "$tmp/META-INF/versions/$ver/$srcsub" ]; then
            mkdir -p "${workdir}/META-INF/versions/$ver/$(dirname "$destsub")"
            cp -a "$tmp/META-INF/versions/$ver/$srcsub" "${workdir}/META-INF/versions/$ver/${destsub}"
        fi
    done

    rm -rf "$tmp"
}

write_pom_properties() {
    local workdir="$1"
    local group="$2"
    local artifact="$3"
    local version="$4"
    mkdir -p "${workdir}/META-INF/maven/${group}/${artifact}"
    cat >"${workdir}/META-INF/maven/${group}/${artifact}/pom.properties" <<EOF
artifactId=${artifact}
groupId=${group}
version=${version}
EOF
}

repack_jar() {
    local jarpath="$1"
    local patch_fn="$2"
    local work
    work="$(mktemp -d)"

    (cd "$work" && jar xf "$jarpath")
    (
        cd "$work"
        "$patch_fn"
    )
    rm -f "$jarpath"
    (cd "$work" && jar cf "$jarpath" .)
    rm -rf "$work"
}

patch_hadoop_jar() {
    relocate_tree "$PWD" "$JACKSON_CORE" com/fasterxml/jackson/core org/apache/hadoop/shaded/com/fasterxml/jackson/core
    relocate_tree "$PWD" "$JACKSON_DATABIND" com/fasterxml/jackson/databind org/apache/hadoop/shaded/com/fasterxml/jackson/databind
    relocate_tree "$PWD" "$JACKSON_ANNOTATIONS" com/fasterxml/jackson/annotation org/apache/hadoop/shaded/com/fasterxml/jackson/annotation
    relocate_tree "$PWD" "$COMMONS_CONFIGURATION2" org/apache/commons/configuration2 org/apache/hadoop/shaded/org/apache/commons/configuration2
    relocate_tree "$PWD" "$JLINE_REMOTE_TELNET" org/jline/builtins/telnet org/apache/hadoop/shaded/org/jline/builtins/telnet
    rm -rf org/apache/hadoop/shaded/org/eclipse/jetty
    rm -rf META-INF/maven/org.eclipse.jetty META-INF/maven/org.eclipse.jetty.websocket
    find META-INF/services -maxdepth 1 -name 'org.apache.hadoop.shaded.org.eclipse.jetty.*' -delete
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-core "${JACKSON_VERSION}"
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-databind "${JACKSON_VERSION}"
    write_pom_properties "$PWD" org.apache.commons commons-configuration2 2.15.0
    write_pom_properties "$PWD" org.jline jline-remote-telnet 4.2.1
}

patch_parquet_jar() {
    relocate_tree "$PWD" "$JACKSON_CORE" com/fasterxml/jackson/core shaded/parquet/com/fasterxml/jackson/core
    relocate_tree "$PWD" "$JACKSON_DATABIND" com/fasterxml/jackson/databind shaded/parquet/com/fasterxml/jackson/databind
    relocate_tree "$PWD" "$JACKSON_ANNOTATIONS" com/fasterxml/jackson/annotation shaded/parquet/com/fasterxml/jackson/annotation
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-core "${JACKSON_VERSION}"
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-databind "${JACKSON_VERSION}"
}

strip_jline_telnet() {
    rm -rf org/jline/builtins/telnet
    rm -rf META-INF/maven/org.jline/jline-remote-telnet
}

replace_loose_jar() {
    local destname="$1"
    local srcjar="$2"
    install -T -m 0644 "$srcjar" "${JARS_DIR}/${destname}"
}

echo "remediating loose jars in ${JARS_DIR}"

rm -f \
    "${JARS_DIR}/derby-10.16.1.1.jar" \
    "${JARS_DIR}/derbyshared-10.16.1.1.jar" \
    "${JARS_DIR}/derbytools-10.16.1.1.jar" \
    "${JARS_DIR}/libthrift-0.16.0.jar" \
    "${JARS_DIR}/hive-jdbc-2.3.10.jar"
install -T -m 0644 "$DERBY" "${JARS_DIR}/derby-10.17.1.0.jar"
install -T -m 0644 "$DERBYSHARED" "${JARS_DIR}/derbyshared-10.17.1.0.jar"
install -T -m 0644 "$DERBYTOOLS" "${JARS_DIR}/derbytools-10.17.1.0.jar"
install -T -m 0644 "$LIBTHRIFT" "${JARS_DIR}/libthrift-0.23.0.jar"

# Spark pins hive-jdbc-2.3.10.jar; install the fixed JDBC driver under that
# name so the distribution classpath layout stays stable.
replace_loose_jar "hive-jdbc-2.3.10.jar" "$HIVE_JDBC_313"

HADOOP_JAR="$(find "${JARS_DIR}" -maxdepth 1 -name 'hadoop-client-runtime-*.jar' -print -quit)"
if [ -n "$HADOOP_JAR" ] && [ -f "$HADOOP_JAR" ]; then
    echo "repacking shaded dependencies in ${HADOOP_JAR}"
    repack_jar "$HADOOP_JAR" patch_hadoop_jar
fi

PARQUET_JAR="$(find "${JARS_DIR}" -maxdepth 1 -name 'parquet-jackson-*.jar' -print -quit)"
if [ -n "$PARQUET_JAR" ] && [ -f "$PARQUET_JAR" ]; then
    echo "repacking shaded jackson in ${PARQUET_JAR}"
    repack_jar "$PARQUET_JAR" patch_parquet_jar
fi

JLINE_UBER="$(find "${JARS_DIR}" -maxdepth 1 -name 'jline-*-jdk8.jar' -print -quit)"
if [ -n "$JLINE_UBER" ] && [ -f "$JLINE_UBER" ]; then
    echo "removing vulnerable telnet support from ${JLINE_UBER}"
    repack_jar "$JLINE_UBER" strip_jline_telnet
fi

echo "jar remediation complete"
