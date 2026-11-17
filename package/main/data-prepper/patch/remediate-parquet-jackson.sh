#!/bin/bash
# Bump shaded Jackson inside parquet-jackson with jarjar bytecode relocation.
# Gradle pins and file-tree copy cannot reach the shaded copy Scout reports, and
# copying class files without relocation breaks this_class (see datahub-upgrade).
# pantsbuild jarjar 1.7.2 with ASM 7 omits META-INF/versions classes (the entry
# path does not match the class name, and Java 17/21 bytecode is unreadable),
# so shaded fdp v2_22_2 multi-release trees would survive a root-only replace.
# jarjar-abrams rewrites those versioned classes in place.
set -euo pipefail

JARS_DIR="${1:?usage: remediate-parquet-jackson.sh <jars-dir> <patch-deps-dir> <jackson-version>}"
PATCH_DIR="${2:?usage: remediate-parquet-jackson.sh <jars-dir> <patch-deps-dir> <jackson-version>}"
JACKSON_VERSION="${3:?usage: remediate-parquet-jackson.sh <jars-dir> <patch-deps-dir> <jackson-version>}"

JACKSON_CORE="${PATCH_DIR}/jackson-core-${JACKSON_VERSION}.jar"
JACKSON_DATABIND="${PATCH_DIR}/jackson-databind-${JACKSON_VERSION}.jar"
JACKSON_ANNOTATIONS="${PATCH_DIR}/jackson-annotations-${JACKSON_VERSION}.jar"
if [ ! -f "$JACKSON_ANNOTATIONS" ]; then
    JACKSON_ANNOTATIONS="${PATCH_DIR}/jackson-annotations-2.22.jar"
fi

JARJAR_VERSION=1.14.1
JARJAR_JAR="${PATCH_DIR}/jarjar-assembly-${JARJAR_VERSION}.jar"
FDP_VERSION="v${JACKSON_VERSION//./_}"

for jar in "$JACKSON_CORE" "$JACKSON_DATABIND" "$JACKSON_ANNOTATIONS" "$JARJAR_JAR"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

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
    (cd "$work" && jar cMf "$jarpath" .)
    rm -rf "$work"
}

merge_jarjar_shaded_tree() {
    local srcjar="$1"
    local shaded_prefix="$2"
    local rules
    local out
    rules="$(mktemp)"
    out="$(mktemp -d)"
    echo 'rule com.fasterxml.jackson.** shaded.parquet.com.fasterxml.jackson.@1' >"$rules"
    java -jar "$JARJAR_JAR" process "$rules" "$srcjar" "$out/relocated.jar"
    rm -f "$rules"

    (cd "$out" && jar xf relocated.jar)
    rm -rf "$shaded_prefix"
    if [ -d META-INF/versions ]; then
        find META-INF/versions -type d -path "*/${shaded_prefix}" -prune -exec rm -rf {} +
    fi
    if [ ! -d "$out/$shaded_prefix" ]; then
        echo "jarjar output missing $shaded_prefix from $srcjar" >&2
        exit 1
    fi
    mkdir -p "$(dirname "$shaded_prefix")"
    cp -a "$out/$shaded_prefix" "$(dirname "$shaded_prefix")/"

    if [ -d "$out/META-INF/services" ]; then
        mkdir -p META-INF/services
        cp -a "$out/META-INF/services/." META-INF/services/
    fi
    for verpath in "$out"/META-INF/versions/*/; do
        [ -d "$verpath" ] || continue
        ver="$(basename "$verpath")"
        if [ -d "$verpath/$shaded_prefix" ]; then
            mkdir -p "META-INF/versions/$ver/$(dirname "$shaded_prefix")"
            cp -a "$verpath/$shaded_prefix" "META-INF/versions/$ver/$(dirname "$shaded_prefix")/"
        fi
    done
    rm -rf "$out"
}

patch_parquet_jar() {
    merge_jarjar_shaded_tree "$JACKSON_CORE" shaded/parquet/com/fasterxml/jackson/core
    merge_jarjar_shaded_tree "$JACKSON_DATABIND" shaded/parquet/com/fasterxml/jackson/databind
    merge_jarjar_shaded_tree "$JACKSON_ANNOTATIONS" shaded/parquet/com/fasterxml/jackson/annotation
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-core "${JACKSON_VERSION}"
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-databind "${JACKSON_VERSION}"

    javap -verbose -classpath . shaded.parquet.com.fasterxml.jackson.core.JsonFactory \
        | grep -q 'this_class:.*shaded/parquet/com/fasterxml/jackson/core/JsonFactory'
    javap -verbose -classpath . shaded.parquet.com.fasterxml.jackson.databind.ObjectMapper \
        | grep -q 'this_class:.*shaded/parquet/com/fasterxml/jackson/databind/ObjectMapper'

    local fdp="shaded/parquet/com/fasterxml/jackson/core/internal/shaded/fdp/${FDP_VERSION}"
    local entry
    for entry in \
        "${fdp}/FastDoubleSwar.class" \
        "META-INF/versions/11/${fdp}/BigSignificand.class" \
        "META-INF/versions/11/${fdp}/FastDoubleSwar.class" \
        "META-INF/versions/11/${fdp}/FastIntegerMath.class" \
        "META-INF/versions/17/${fdp}/FastDoubleSwar.class" \
        "META-INF/versions/17/${fdp}/FastIntegerMath.class" \
        "META-INF/versions/21/${fdp}/FastDoubleSwar.class" \
        "META-INF/versions/21/${fdp}/FastIntegerMath.class"
    do
        if [ ! -f "$entry" ]; then
            echo "missing relocated jackson ${JACKSON_VERSION} class: ${entry}" >&2
            exit 1
        fi
    done

    local stale
    stale="$(find . -name '*.class' -path '*v2_22_2*' -print)"
    if [ -n "$stale" ]; then
        echo "stale jackson 2.22.2 classes remain:" >&2
        echo "$stale" >&2
        exit 1
    fi

    javap -verbose "META-INF/versions/21/${fdp}/FastDoubleSwar.class" \
        | grep -q "this_class:.*shaded/parquet/com/fasterxml/jackson/core/internal/shaded/fdp/${FDP_VERSION}/FastDoubleSwar"
}

PARQUET_JAR="$(find "${JARS_DIR}" -maxdepth 1 -name 'parquet-jackson-*.jar' -print -quit)"
if [ -n "$PARQUET_JAR" ] && [ -f "$PARQUET_JAR" ]; then
    echo "repacking shaded jackson ${JACKSON_VERSION} in ${PARQUET_JAR}"
    repack_jar "$PARQUET_JAR" patch_parquet_jar
else
    echo "parquet-jackson jar not found under ${JARS_DIR}" >&2
    exit 1
fi

echo "parquet-jackson remediation complete"
