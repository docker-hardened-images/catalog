#!/bin/bash
# Patch shaded Guava inside graphql-java-*.jar and iceberg-bundled-guava-*.jar in war.war.
#
# Gradle resolutionStrategy fixes loose guava coordinates; scanners still flag shaded
# copies. File copy without bytecode relocation breaks this_class (NoClassDefFoundError).
# jarjar rewrites com.google.common.** into the graphql / iceberg relocated prefixes.
set -euo pipefail

WAR_PATH="${1:?usage: patch-shaded-guava.sh <war.war>}"
PATCH_DIR="${2:?usage: patch-shaded-guava.sh <war.war> <patch-deps-dir>}"

GUAVA_JAR="${PATCH_DIR}/guava-33.7.2-jre.jar"
FAILUREACCESS_JAR="${PATCH_DIR}/failureaccess-1.0.3.jar"
JARJAR_VERSION=1.7.2
JARJAR_CP="${PATCH_DIR}/jarjar-${JARJAR_VERSION}.jar:${PATCH_DIR}/asm-7.0.jar:${PATCH_DIR}/asm-commons-7.0.jar"

for jar in "$GUAVA_JAR" "$FAILUREACCESS_JAR" \
    "${PATCH_DIR}/jarjar-${JARJAR_VERSION}.jar" \
    "${PATCH_DIR}/asm-7.0.jar" "${PATCH_DIR}/asm-commons-7.0.jar"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

WAR_WORK="$(mktemp -d)"
trap 'rm -rf "$WAR_WORK"' EXIT

cd "$WAR_WORK"
jar xf "$WAR_PATH"

for old in BOOT-INF/lib/guava-*.jar; do
    if [ -f "$old" ]; then
        zip -d "$WAR_PATH" "$old" >/dev/null
        rm -f "$old"
    fi
done

cp "$GUAVA_JAR" BOOT-INF/lib/guava-33.7.2-jre.jar

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
    local jarjar_rule="$3"
    local rules
    local out
    rules="$(mktemp)"
    out="$(mktemp -d)"
    echo "$jarjar_rule" >"$rules"
    java -cp "$JARJAR_CP" org.pantsbuild.jarjar.Main process "$rules" "$srcjar" "$out/relocated.jar"
    rm -f "$rules"

    (cd "$out" && jar xf relocated.jar)
    rm -rf "$shaded_prefix"
    if [ -d META-INF/versions ]; then
        find META-INF/versions -type d -path "*/${shaded_prefix}" -prune -exec rm -rf {} + 2>/dev/null || true
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

build_guava_reloc_input() {
    local outjar="$1"
    local work
    work="$(mktemp -d)"
    (
        cd "$work"
        jar xf "$GUAVA_JAR"
        jar xf "$FAILUREACCESS_JAR"
        jar cf "$outjar" .
    )
    rm -rf "$work"
}

verify_relocated_guava_closure() {
    local prefix="$1"
    local preconditions="${prefix}.base.Preconditions"
    local abstract_future="${prefix}.util.concurrent.AbstractFuture"
    local internal_fa="${prefix}.util.concurrent.internal.InternalFutureFailureAccess"
    local preconditions_path
    local abstract_future_path
    local internal_fa_path

    case "$prefix" in
        graphql.com.google.common)
            preconditions_path='graphql/com/google/common/base/Preconditions'
            abstract_future_path='graphql/com/google/common/util/concurrent/AbstractFuture'
            internal_fa_path='graphql/com/google/common/util/concurrent/internal/InternalFutureFailureAccess'
            ;;
        org.apache.iceberg.relocated.com.google.common)
            preconditions_path='org/apache/iceberg/relocated/com/google/common/base/Preconditions'
            abstract_future_path='org/apache/iceberg/relocated/com/google/common/util/concurrent/AbstractFuture'
            internal_fa_path='org/apache/iceberg/relocated/com/google/common/util/concurrent/internal/InternalFutureFailureAccess'
            ;;
        *)
            echo "unknown relocated guava prefix: $prefix" >&2
            return 1
            ;;
    esac

    javap -verbose -classpath . "$preconditions" \
        | grep -q "this_class:.*${preconditions_path}"
    javap -classpath . "$internal_fa" >/dev/null
    javap -verbose -classpath . "$internal_fa" \
        | grep -q "this_class:.*${internal_fa_path}"
    javap -classpath . "$abstract_future" >/dev/null
    javap -verbose -classpath . "$abstract_future" \
        | grep -q "this_class:.*${abstract_future_path}"
    javap -verbose -classpath . "$abstract_future" \
        | grep -q "$internal_fa_path"
}

patch_graphql_jar() {
    local input
    input="$(mktemp)"
    build_guava_reloc_input "$input"
    merge_jarjar_shaded_tree "$input" graphql/com/google/common \
        'rule com.google.common.** graphql.com.google.common.@1'
    rm -f "$input"
    write_pom_properties "$PWD" com.google.guava guava 33.7.2-jre
    write_pom_properties "$PWD" com.google.guava failureaccess 1.0.3

    verify_relocated_guava_closure graphql.com.google.common
}

patch_iceberg_guava_jar() {
    local input
    input="$(mktemp)"
    build_guava_reloc_input "$input"
    merge_jarjar_shaded_tree "$input" org/apache/iceberg/relocated/com/google/common \
        'rule com.google.common.** org.apache.iceberg.relocated.com.google.common.@1'
    rm -f "$input"
    write_pom_properties "$PWD" com.google.guava guava 33.7.2-jre
    write_pom_properties "$PWD" com.google.guava failureaccess 1.0.3

    verify_relocated_guava_closure org.apache.iceberg.relocated.com.google.common
}

for lib_jar in BOOT-INF/lib/graphql-java-*.jar; do
    [ -f "$lib_jar" ] || continue
    repack_jar "$WAR_WORK/$lib_jar" patch_graphql_jar
done

for lib_jar in BOOT-INF/lib/iceberg-bundled-guava-*.jar; do
    [ -f "$lib_jar" ] || continue
    repack_jar "$WAR_WORK/$lib_jar" patch_iceberg_guava_jar
done

(
    cd "$WAR_WORK"
    jar uf "$WAR_PATH" BOOT-INF/lib/guava-33.7.2-jre.jar
    for lib_jar in BOOT-INF/lib/graphql-java-*.jar BOOT-INF/lib/iceberg-bundled-guava-*.jar; do
        [ -f "$lib_jar" ] || continue
        jar uf "$WAR_PATH" "$lib_jar"
    done
)

VERIFY_WORK="$(mktemp -d)"
(
    cd "$VERIFY_WORK"
    jar xf "$WAR_PATH" META-INF/MANIFEST.MF
    grep -q 'Spring-Boot-Version:' META-INF/MANIFEST.MF
)
rm -rf "$VERIFY_WORK"
