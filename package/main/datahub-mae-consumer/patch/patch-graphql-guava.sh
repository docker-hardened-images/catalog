#!/bin/bash
# Patch shaded Guava inside graphql-java-*.jar embedded in the Spring Boot jar.
#
# graphql-java 22.x bundles guava 32.1.2-jre under graphql/com/google/common.
# Gradle resolutionStrategy cannot replace those bytes. jarjar rewrites guava
# 33.7.2-jre and its failureaccess runtime jar into graphql.com.google.common.*
# (CVE-2026-102554). AbstractFuture extends InternalFutureFailureAccess, which
# lives only in failureaccess; relocating guava alone leaves that superclass
# unloadable. Maven pom.xml and pom.properties are copied from the fixed guava
# artifact so the embedded metadata is not a mix of 32.1.2-jre and 33.7.2-jre.
set -euo pipefail

BOOT_JAR="${1:?usage: patch-graphql-guava.sh <boot.jar> <patch-deps-dir>}"
PATCH_DIR="${2:?usage: patch-graphql-guava.sh <boot.jar> <patch-deps-dir>}"

GUAVA_VERSION=33.7.2-jre
FAILUREACCESS_VERSION=1.0.3
GUAVA_JAR="${PATCH_DIR}/guava-${GUAVA_VERSION}.jar"
FAILUREACCESS_JAR="${PATCH_DIR}/failureaccess-${FAILUREACCESS_VERSION}.jar"
JARJAR_VERSION=1.14.1
JARJAR_JAR="${PATCH_DIR}/jarjar-assembly-${JARJAR_VERSION}.jar"
SHADED_PREFIX=graphql/com/google/common

for jar in "$GUAVA_JAR" "$FAILUREACCESS_JAR" "$JARJAR_JAR"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

clear_shaded_tree() {
    local shaded_prefix="$1"
    rm -rf "$shaded_prefix"
    if [ -d META-INF/versions ]; then
        find META-INF/versions -type d -path "*/${shaded_prefix}" -prune -exec rm -rf {} +
    fi
}

merge_jarjar_shaded_tree() {
    local srcjar="$1"
    local shaded_prefix="$2"
    local rules
    local out
    rules="$(mktemp)"
    out="$(mktemp -d)"
    echo 'rule com.google.common.** graphql.com.google.common.@1' >"$rules"
    java -jar "$JARJAR_JAR" process "$rules" "$srcjar" "$out/relocated.jar"
    rm -f "$rules"

    (cd "$out" && jar xf relocated.jar)
    if [ ! -d "$out/$shaded_prefix" ]; then
        echo "jarjar output missing $shaded_prefix from $srcjar" >&2
        exit 1
    fi
    mkdir -p "$shaded_prefix"
    cp -a "$out/$shaded_prefix/." "$shaded_prefix/"

    if [ -d "$out/META-INF/services" ]; then
        mkdir -p META-INF/services
        cp -a "$out/META-INF/services/." META-INF/services/
    fi
    for verpath in "$out"/META-INF/versions/*/; do
        [ -d "$verpath" ] || continue
        ver="$(basename "$verpath")"
        if [ -d "$verpath/$shaded_prefix" ]; then
            mkdir -p "META-INF/versions/$ver/$shaded_prefix"
            cp -a "$verpath/$shaded_prefix/." "META-INF/versions/$ver/$shaded_prefix/"
        fi
    done
    rm -rf "$out"
}

install_fixed_maven_metadata() {
    local srcjar="$1"
    local group="$2"
    local artifact="$3"
    local meta="META-INF/maven/${group}/${artifact}"
    local tmp
    tmp="$(mktemp -d)"
    (cd "$tmp" && jar xf "$srcjar" "${meta}/pom.xml" "${meta}/pom.properties")
    if [ ! -f "$tmp/${meta}/pom.xml" ] || [ ! -f "$tmp/${meta}/pom.properties" ]; then
        echo "fixed artifact missing maven metadata: $srcjar" >&2
        exit 1
    fi
    mkdir -p "$meta"
    cp -a "$tmp/${meta}/pom.xml" "$tmp/${meta}/pom.properties" "$meta/"
    rm -rf "$tmp"
}

assert_guava_metadata() {
    local props="META-INF/maven/com.google.guava/guava/pom.properties"
    local pom="META-INF/maven/com.google.guava/guava/pom.xml"
    grep -q "version=${GUAVA_VERSION}" "$props"
    grep -q "<version>${GUAVA_VERSION}</version>" "$pom"
    if grep -q '32.1.2-jre' "$pom" "$props"; then
        echo "guava maven metadata still names 32.1.2-jre" >&2
        exit 1
    fi
}

assert_class_loads() {
    local classname="$1"
    local load_out
    load_out="$(mktemp)"
    if java -classpath . "$classname" >"$load_out" 2>&1; then
        echo "$classname unexpectedly defined a main method" >&2
        rm -f "$load_out"
        exit 1
    fi
    if ! grep -q 'Main method not found' "$load_out"; then
        echo "$classname failed to load" >&2
        cat "$load_out" >&2
        rm -f "$load_out"
        exit 1
    fi
    rm -f "$load_out"
}

patch_graphql_jar() {
    clear_shaded_tree "$SHADED_PREFIX"
    merge_jarjar_shaded_tree "$GUAVA_JAR" "$SHADED_PREFIX"
    merge_jarjar_shaded_tree "$FAILUREACCESS_JAR" "$SHADED_PREFIX"
    install_fixed_maven_metadata "$GUAVA_JAR" com.google.guava guava
    assert_guava_metadata

    if find . -path './com/google/common/*.class' | grep -q .; then
        echo "unshaded com/google/common classes must not remain in graphql-java jar" >&2
        exit 1
    fi

    javap -verbose -classpath . graphql.com.google.common.base.Preconditions \
        | grep -q 'this_class:.*graphql/com/google/common/base/Preconditions'
    javap -verbose -classpath . graphql.com.google.common.util.concurrent.internal.InternalFutureFailureAccess \
        | grep -q 'this_class:.*graphql/com/google/common/util/concurrent/internal/InternalFutureFailureAccess'
    javap -verbose -classpath . graphql.com.google.common.util.concurrent.AbstractFuture \
        | grep -q 'this_class:.*graphql/com/google/common/util/concurrent/AbstractFuture'

    assert_class_loads graphql.com.google.common.util.concurrent.AbstractFuture
    assert_class_loads graphql.com.google.common.base.Preconditions

    javap -classpath . graphql.GraphQL >/dev/null
}

BOOT_WORK="$(mktemp -d)"
trap 'rm -rf "$BOOT_WORK"' EXIT

cd "$BOOT_WORK"
jar xf "$BOOT_JAR"

GRAPHQL_JAR="$(find BOOT-INF/lib -maxdepth 1 -type f -name 'graphql-java-*.jar' | sort | head -1)"
if [ -z "$GRAPHQL_JAR" ]; then
    echo "no graphql-java jar in $BOOT_JAR" >&2
    exit 1
fi

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

repack_jar "$BOOT_WORK/$GRAPHQL_JAR" patch_graphql_jar

jar tf "$BOOT_WORK/$GRAPHQL_JAR" | grep -q 'graphql/com/google/common/base/Preconditions.class'
jar tf "$BOOT_WORK/$GRAPHQL_JAR" | grep -q 'graphql/com/google/common/util/concurrent/internal/InternalFutureFailureAccess.class'

(cd "$BOOT_WORK" && jar uf "$BOOT_JAR" "$GRAPHQL_JAR")

VERIFY_MANIFEST="$(mktemp -d)"
(
    cd "$VERIFY_MANIFEST"
    jar xf "$BOOT_JAR" META-INF/MANIFEST.MF
    grep -q 'Spring-Boot-Version:' META-INF/MANIFEST.MF
)
rm -rf "$VERIFY_MANIFEST"
