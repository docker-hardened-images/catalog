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
JACKSON_ANNOTATIONS_VERSION="${JACKSON_VERSION}"
if [ "${JACKSON_VERSION}" = "2.21.7" ]; then
    JACKSON_ANNOTATIONS_VERSION="2.21"
fi
JACKSON_ANNOTATIONS="${PATCH_DIR}/jackson-annotations-${JACKSON_ANNOTATIONS_VERSION}.jar"
COMMONS_CONFIGURATION2="${PATCH_DIR}/commons-configuration2-2.15.0.jar"
JLINE_REMOTE_TELNET="${PATCH_DIR}/jline-remote-telnet-4.2.1.jar"
JLINE_UBER_JAR="${PATCH_DIR}/jline-3.30.17-jdk8.jar"
JARJAR_JAR="${PATCH_DIR}/jarjar-assembly-1.14.1.jar"
DERBY="${PATCH_DIR}/derby-10.17.1.0.jar"
DERBYSHARED="${PATCH_DIR}/derbyshared-10.17.1.0.jar"
DERBYTOOLS="${PATCH_DIR}/derbytools-10.17.1.0.jar"
LIBTHRIFT="${PATCH_DIR}/libthrift-0.24.0.jar"
HIVE_JDBC_313="${PATCH_DIR}/hive-jdbc-3.1.3.jar"
HIVE_EXEC_401_CORE="${PATCH_DIR}/hive-exec-4.0.1-core.jar"
COMMONS_LANG3="${PATCH_DIR}/commons-lang3-3.18.0.jar"
NIMBUS_JOSE_JWT="${PATCH_DIR}/nimbus-jose-jwt-10.0.2.jar"

for jar in \
    "$JACKSON_CORE" "$JACKSON_DATABIND" "$JACKSON_ANNOTATIONS" \
    "$COMMONS_CONFIGURATION2" "$JLINE_REMOTE_TELNET" "$JLINE_UBER_JAR" "$JARJAR_JAR" \
    "$DERBY" "$DERBYSHARED" "$DERBYTOOLS" "$LIBTHRIFT" \
    "$HIVE_JDBC_313" "$HIVE_EXEC_401_CORE" "$COMMONS_LANG3" "$NIMBUS_JOSE_JWT"; do
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

# Hadoop's hadoop-client-runtime shade relocates pattern org/ to
# org.apache.hadoop.shaded.org. and excludes slf4j. jarjar applies that
# relocation to commons-configuration2 and JLine bytecode, rewriting
# this_class and constant-pool names. A path-only copy leaves unshaded
# package names and the JVM rejects the shaded path.
relocate_jline_jar() {
    local srcjar="$1"
    local outjar="$2"
    local rules
    rules="$(mktemp)"
    cat >"$rules" <<'EOF'
rule org.jline.** org.apache.hadoop.shaded.org.jline.@1
rule org.apache.sshd.** org.apache.hadoop.shaded.org.apache.sshd.@1
rule org.mozilla.** org.apache.hadoop.shaded.org.mozilla.@1
EOF
    java -jar "$JARJAR_JAR" process "$rules" "$srcjar" "$outjar"
    rm -f "$rules"
}

copy_relocated_tree() {
    local srcdir="$1"
    local destsub="$2"
    if [ ! -d "$srcdir" ]; then
        echo "missing relocated tree: $srcdir" >&2
        exit 1
    fi
    rm -rf "$destsub"
    find META-INF/versions -type d -path "*/${destsub}" -prune -exec rm -rf {} + 2>/dev/null || true
    mkdir -p "$(dirname "$destsub")"
    cp -a "$srcdir" "$(dirname "$destsub")/"
}

assert_shaded_class_loads() {
    local classname="$1"
    local dir
    dir="$(mktemp -d)"
    cat >"$dir/LoadShaded.java" <<'EOF'
public class LoadShaded {
    public static void main(String[] args) throws Exception {
        Class<?> loaded = Class.forName(args[0], false, ClassLoader.getSystemClassLoader());
        if (!loaded.getName().equals(args[0])) {
            throw new AssertionError(loaded.getName());
        }
    }
}
EOF
    javac -d "$dir" "$dir/LoadShaded.java"
    java -cp "$dir:." LoadShaded "$classname"
    rm -rf "$dir"
}

install_shaded_jline() {
    local uber_dir telnet_dir
    local prefix reader builtins telnet
    local classfile base count
    uber_dir="$(mktemp -d)"
    telnet_dir="$(mktemp -d)"
    relocate_jline_jar "$JLINE_UBER_JAR" "$uber_dir/reloc.jar"
    relocate_jline_jar "$JLINE_REMOTE_TELNET" "$telnet_dir/reloc.jar"
    (cd "$uber_dir" && jar xf reloc.jar)
    (cd "$telnet_dir" && jar xf reloc.jar)

    prefix="org/apache/hadoop/shaded/org/jline"
    reader="${prefix}/reader"
    builtins="${prefix}/builtins"
    telnet="${prefix}/builtins/telnet"

    copy_relocated_tree "$uber_dir/$reader" "$reader"
    copy_relocated_tree "$uber_dir/$builtins" "$builtins"
    # The uber jar's builtins tree contains jline 3.30.17 telnet classes.
    # Replace that directory with relocated jline-remote-telnet 4.2.1.
    copy_relocated_tree "$telnet_dir/$telnet" "$telnet"

    count=0
    for classfile in "$telnet_dir/$telnet"/*.class; do
        count=$((count + 1))
        base="$(basename "$classfile")"
        if ! cmp -s "$classfile" "$telnet/$base"; then
            echo "telnet class does not match jline-remote-telnet 4.2.1: $base" >&2
            exit 1
        fi
    done
    if [ "$count" -ne 18 ]; then
        echo "expected 18 jline-remote-telnet 4.2.1 classes, found $count" >&2
        exit 1
    fi
    if cmp -s "$uber_dir/$telnet/Telnet.class" "$telnet/Telnet.class"; then
        echo "installed telnet classes are still jline 3.30.17" >&2
        exit 1
    fi

    assert_shaded_class_loads org.apache.hadoop.shaded.org.jline.reader.LineReader
    assert_shaded_class_loads org.apache.hadoop.shaded.org.jline.builtins.telnet.Telnet
    if ! javap -verbose -classpath . org.apache.hadoop.shaded.org.jline.reader.LineReader \
        | grep -q 'this_class:.*org/apache/hadoop/shaded/org/jline/reader/LineReader'; then
        echo "LineReader this_class is not the Hadoop shaded name" >&2
        exit 1
    fi
    if ! javap -verbose -classpath . org.apache.hadoop.shaded.org.jline.builtins.telnet.Telnet \
        | grep -q 'this_class:.*org/apache/hadoop/shaded/org/jline/builtins/telnet/Telnet'; then
        echo "Telnet this_class is not the Hadoop shaded name" >&2
        exit 1
    fi

    rm -rf "$uber_dir" "$telnet_dir"
}

relocate_commons_configuration2_jar() {
    local srcjar="$1"
    local outjar="$2"
    local rules
    rules="$(mktemp)"
    cat >"$rules" <<'EOF'
rule org.apache.commons.configuration2.** org.apache.hadoop.shaded.org.apache.commons.configuration2.@1
EOF
    java -jar "$JARJAR_JAR" process "$rules" "$srcjar" "$outjar"
    rm -f "$rules"
}

install_shaded_commons_configuration2() {
    local work_dir prefix
    work_dir="$(mktemp -d)"
    relocate_commons_configuration2_jar "$COMMONS_CONFIGURATION2" "$work_dir/reloc.jar"
    (cd "$work_dir" && jar xf reloc.jar)

    prefix="org/apache/hadoop/shaded/org/apache/commons/configuration2"
    copy_relocated_tree "$work_dir/$prefix" "$prefix"

    assert_shaded_class_loads org.apache.hadoop.shaded.org.apache.commons.configuration2.AbstractConfiguration
    if ! javap -verbose -classpath . org.apache.hadoop.shaded.org.apache.commons.configuration2.AbstractConfiguration \
        | grep -q 'this_class:.*org/apache/hadoop/shaded/org/apache/commons/configuration2/AbstractConfiguration'; then
        echo "AbstractConfiguration this_class is not the Hadoop shaded name" >&2
        exit 1
    fi

    rm -rf "$work_dir"
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
    install_shaded_commons_configuration2
    install_shaded_jline
    relocate_tree "$PWD" "$COMMONS_LANG3" org/apache/commons/lang3 org/apache/hadoop/shaded/org/apache/commons/lang3
    relocate_tree "$PWD" "$NIMBUS_JOSE_JWT" com/nimbusds org/apache/hadoop/shaded/com/nimbusds
    rm -rf org/apache/hadoop/shaded/org/eclipse/jetty
    rm -rf META-INF/maven/org.eclipse.jetty META-INF/maven/org.eclipse.jetty.websocket
    find META-INF/services -maxdepth 1 -name 'org.apache.hadoop.shaded.org.eclipse.jetty.*' -delete
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-core "${JACKSON_VERSION}"
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-databind "${JACKSON_VERSION}"
    write_pom_properties "$PWD" org.apache.commons commons-configuration2 2.15.0
    write_pom_properties "$PWD" org.apache.commons commons-lang3 3.18.0
    write_pom_properties "$PWD" org.jline jline-remote-telnet 4.2.1
    write_pom_properties "$PWD" org.jline jline-reader 3.30.17
    write_pom_properties "$PWD" org.jline jline-builtins 3.30.17
    grep -q '^version=4.2.1$' META-INF/maven/org.jline/jline-remote-telnet/pom.properties
    grep -q '^version=3.30.17$' META-INF/maven/org.jline/jline-reader/pom.properties
    grep -q '^version=3.30.17$' META-INF/maven/org.jline/jline-builtins/pom.properties
    write_pom_properties "$PWD" com.nimbusds nimbus-jose-jwt 10.0.2
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
    "${JARS_DIR}/libthrift-0.23.0.jar" \
    "${JARS_DIR}/hive-jdbc-2.3.10.jar"
install -T -m 0644 "$DERBY" "${JARS_DIR}/derby-10.17.1.0.jar"
install -T -m 0644 "$DERBYSHARED" "${JARS_DIR}/derbyshared-10.17.1.0.jar"
install -T -m 0644 "$DERBYTOOLS" "${JARS_DIR}/derbytools-10.17.1.0.jar"
install -T -m 0644 "$LIBTHRIFT" "${JARS_DIR}/libthrift-0.24.0.jar"

# Spark pins hive-jdbc-2.3.10.jar; install the fixed JDBC driver under that
# name so the distribution classpath layout stays stable.
replace_loose_jar "hive-jdbc-2.3.10.jar" "$HIVE_JDBC_313"

# Spark ships hive-exec-2.3.10-core.jar from the Hive 2.3 profile; swap in
# the fixed core artifact while keeping the legacy filename on the classpath.
replace_loose_jar "hive-exec-2.3.10-core.jar" "$HIVE_EXEC_401_CORE"

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
    destname="$(basename "$JLINE_UBER")"
    echo "replacing ${JLINE_UBER} with jline 3.30.17 (${destname})"
    replace_loose_jar "$destname" "$JLINE_UBER_JAR"
fi

echo "jar remediation complete"
