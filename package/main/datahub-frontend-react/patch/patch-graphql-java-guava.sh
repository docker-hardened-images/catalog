#!/bin/bash
# graphql-java 22.3 shades Guava 32.1.2-jre into graphql.com.google.common.
# DataHub locks that coordinate, so replace the relocated class files and
# refresh the embedded Maven metadata to Guava 33.7.2-jre. Stripping the
# metadata hides the component from the scanner without changing bytecode.
set -euo pipefail

GJ_JAR="${1:?usage: patch-graphql-java-guava.sh <graphql-java.jar> <patch-deps-dir>}"
PATCH_DIR="${2:?usage: patch-graphql-java-guava.sh <graphql-java.jar> <patch-deps-dir>}"

GUAVA_VERSION="33.7.2-jre"
GUAVA_JAR="${PATCH_DIR}/guava-${GUAVA_VERSION}.jar"
JARJAR_JAR="${PATCH_DIR}/jarjar-assembly-1.14.1.jar"

for jar in "$GUAVA_JAR" "$JARJAR_JAR" "$GJ_JAR"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat >"${WORK}/rules.txt" <<'EOF'
rule com.google.common.base.** graphql.com.google.common.base.@1
rule com.google.common.collect.** graphql.com.google.common.collect.@1
rule com.google.common.math.** graphql.com.google.common.math.@1
rule com.google.common.primitives.** graphql.com.google.common.primitives.@1
EOF

java -jar "$JARJAR_JAR" process "${WORK}/rules.txt" "$GUAVA_JAR" "${WORK}/guava-relocated.jar"

if jar tf "${WORK}/guava-relocated.jar" | grep -q '^META-INF/versions/.*/com/google/common/'; then
    echo "guava multi-release classes are not handled" >&2
    exit 1
fi

mkdir -p "${WORK}/gj" "${WORK}/relocated"
(cd "${WORK}/gj" && jar xf "$GJ_JAR")
(cd "${WORK}/relocated" && jar xf "${WORK}/guava-relocated.jar")

for pkg in base collect math primitives; do
    if [ ! -d "${WORK}/gj/graphql/com/google/common/${pkg}" ]; then
        echo "graphql-java is missing shaded guava package ${pkg}" >&2
        exit 1
    fi
    if [ ! -d "${WORK}/relocated/graphql/com/google/common/${pkg}" ]; then
        echo "relocated guava is missing package ${pkg}" >&2
        exit 1
    fi
    rm -rf "${WORK}/gj/graphql/com/google/common/${pkg}"
    cp -a "${WORK}/relocated/graphql/com/google/common/${pkg}" "${WORK}/gj/graphql/com/google/common/${pkg}"
done

META="${WORK}/gj/META-INF/maven/com.google.guava/guava"
mkdir -p "$META"
(cd "${WORK}/gj" && jar xf "$GUAVA_JAR" "META-INF/maven/com.google.guava/guava/pom.properties" "META-INF/maven/com.google.guava/guava/pom.xml")

if ! grep -q '^version=33.7.2-jre$' "${META}/pom.properties"; then
    echo "embedded guava pom.properties is not 33.7.2-jre" >&2
    cat "${META}/pom.properties" >&2
    exit 1
fi
if grep -q '32.1.2' "${META}/pom.properties" "${META}/pom.xml"; then
    echo "embedded guava metadata still names 32.1.2" >&2
    exit 1
fi

rm -f "$GJ_JAR"
(cd "${WORK}/gj" && jar cMf "$GJ_JAR" .)

javap -v -classpath "$GJ_JAR" graphql.com.google.common.collect.MapMakerInternalMap \
    | grep -q 'this_class:.*graphql/com/google/common/collect/MapMakerInternalMap'

javap -c -p -classpath "$GJ_JAR" 'graphql.com.google.common.collect.MapMakerInternalMap$AbstractSerializationProxy' \
    | grep -q 'sipush        256'
javap -c -p -classpath "$GJ_JAR" 'graphql.com.google.common.collect.MapMakerInternalMap$AbstractSerializationProxy' \
    | grep -q 'java/lang/Math.min:(II)I'

if ! jar tf "$GJ_JAR" | grep -q '^META-INF/maven/com.google.guava/guava/pom.properties$'; then
    echo "graphql-java lost guava maven metadata" >&2
    exit 1
fi
mkdir -p "${WORK}/check"
(cd "${WORK}/check" && jar xf "$GJ_JAR" META-INF/maven/com.google.guava/guava/pom.properties)
if ! grep -q '^version=33.7.2-jre$' "${WORK}/check/META-INF/maven/com.google.guava/guava/pom.properties"; then
    echo "repacked pom.properties is not 33.7.2-jre" >&2
    exit 1
fi

echo "replaced shaded guava in ${GJ_JAR} with ${GUAVA_VERSION}"
