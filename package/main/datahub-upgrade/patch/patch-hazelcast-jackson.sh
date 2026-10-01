#!/bin/bash
# Patch shaded Jackson copies inside hazelcast-*.jar and parquet-jackson-*.jar
# embedded in the Spring Boot fat jar.
#
# DataHub 1.6 ships Hazelcast 5.7.0 with shaded jackson-core/databind 2.21.2 and
# tools.jackson 3.1.2. Gradle resolutionStrategy cannot reach those copies, so we
# replace fixed jackson JAR contents into com.hazelcast.shaded.* after the fat jar
# is built. parquet-jackson 1.18.1 embeds jackson 2.22.2 under shaded/parquet/...;
# bump to 2.22.3 with jarjar bytecode relocation (file copy breaks this_class).
set -euo pipefail

WAR_PATH="${1:?usage: patch-hazelcast-jackson.sh <war.war> <patch-deps-dir>}"
PATCH_DIR="${2:?usage: patch-hazelcast-jackson.sh <war.war> <patch-deps-dir>}"

JACKSON_CORE_2="${PATCH_DIR}/jackson-core-2.21.7.jar"
JACKSON_DATABIND_2="${PATCH_DIR}/jackson-databind-2.21.7.jar"
JACKSON_CORE_22="${PATCH_DIR}/jackson-core-2.22.3.jar"
JACKSON_DATABIND_22="${PATCH_DIR}/jackson-databind-2.22.3.jar"
JACKSON_ANNOTATIONS_22="${PATCH_DIR}/jackson-annotations-2.22.jar"
JACKSON_CORE_3="${PATCH_DIR}/tools-jackson-core-3.1.7.jar"
JACKSON_DATABIND_3="${PATCH_DIR}/tools-jackson-databind-3.1.7.jar"
BCPROV_185="${PATCH_DIR}/bcprov-jdk18on-1.85.jar"

JARJAR_VERSION=1.7.2
JARJAR_CP="${PATCH_DIR}/jarjar-${JARJAR_VERSION}.jar:${PATCH_DIR}/asm-7.0.jar:${PATCH_DIR}/asm-commons-7.0.jar"

for jar in "$JACKSON_CORE_2" "$JACKSON_DATABIND_2" \
    "$JACKSON_CORE_22" "$JACKSON_DATABIND_22" "$JACKSON_ANNOTATIONS_22" \
    "$JACKSON_CORE_3" "$JACKSON_DATABIND_3" "$BCPROV_185" \
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

# Match hazelcast-<version>.jar only; hazelcast-spring-*.jar also matches hazelcast-*.
HZ_JAR="$(find BOOT-INF/lib -maxdepth 1 -type f -name 'hazelcast-[0-9]*.jar' | sort | head -1)"
if [ -z "$HZ_JAR" ]; then
    echo "no hazelcast jar in $WAR_PATH" >&2
    exit 1
fi

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
    # cM keeps the extracted META-INF/MANIFEST.MF. Plain cf replaces it.
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
    java -cp "$JARJAR_CP" org.pantsbuild.jarjar.Main process "$rules" "$srcjar" "$out/relocated.jar"
    rm -f "$rules"

    (cd "$out" && jar xf relocated.jar)
    rm -rf "$shaded_prefix"
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

patch_hazelcast_jar() {
    relocate_tree "$PWD" "$JACKSON_CORE_2" com/fasterxml/jackson/core com/hazelcast/shaded/com/fasterxml/jackson/core
    relocate_tree "$PWD" "$JACKSON_DATABIND_2" com/fasterxml/jackson/databind com/hazelcast/shaded/com/fasterxml/jackson/databind
    relocate_tree "$PWD" "$JACKSON_CORE_3" tools/jackson/core com/hazelcast/shaded/tools/jackson/core
    relocate_tree "$PWD" "$JACKSON_DATABIND_3" tools/jackson/databind com/hazelcast/shaded/tools/jackson/databind
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-core 2.21.7
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-databind 2.21.7
    write_pom_properties "$PWD" tools.jackson.core jackson-core 3.1.7
    write_pom_properties "$PWD" tools.jackson.core jackson-databind 3.1.7
}

patch_parquet_jar() {
    merge_jarjar_shaded_tree "$JACKSON_CORE_22" shaded/parquet/com/fasterxml/jackson/core
    merge_jarjar_shaded_tree "$JACKSON_DATABIND_22" shaded/parquet/com/fasterxml/jackson/databind
    merge_jarjar_shaded_tree "$JACKSON_ANNOTATIONS_22" shaded/parquet/com/fasterxml/jackson/annotation
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-core 2.22.3
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-databind 2.22.3

    javap -verbose -classpath . shaded.parquet.com.fasterxml.jackson.core.JsonFactory \
        | grep -q 'this_class:.*shaded/parquet/com/fasterxml/jackson/core/JsonFactory'
}

repack_jar "$WAR_WORK/$HZ_JAR" patch_hazelcast_jar

jar tf "$WAR_WORK/$HZ_JAR" | grep -q 'com/hazelcast/shaded/com/fasterxml/jackson/core/JsonFactory.class'
jar tf "$WAR_WORK/$HZ_JAR" | grep -q 'com/hazelcast/shaded/tools/jackson/databind/ObjectMapper.class'

VERIFY_WORK="$(mktemp -d)"
(
    cd "$VERIFY_WORK"
    jar xf "$WAR_WORK/$HZ_JAR" \
        META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties \
        META-INF/maven/com.fasterxml.jackson.core/jackson-databind/pom.properties \
        META-INF/maven/tools.jackson.core/jackson-databind/pom.properties
    grep -q 'version=2.21.7' META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties
    grep -q 'version=2.21.7' META-INF/maven/com.fasterxml.jackson.core/jackson-databind/pom.properties
    grep -q 'version=3.1.7' META-INF/maven/tools.jackson.core/jackson-databind/pom.properties
)
rm -rf "$VERIFY_WORK"

(cd "$WAR_WORK" && jar uf "$WAR_PATH" "$HZ_JAR")

PARQUET_JAR="$(find "$WAR_WORK/BOOT-INF/lib" -maxdepth 1 -type f -name 'parquet-jackson-*.jar' | sort | head -1 || true)"
if [ -n "$PARQUET_JAR" ]; then
    PARQUET_REL="${PARQUET_JAR#"$WAR_WORK/"}"
    repack_jar "$WAR_WORK/$PARQUET_REL" patch_parquet_jar
    VERIFY_PARQUET="$(mktemp -d)"
    (
        cd "$VERIFY_PARQUET"
        jar xf "$WAR_WORK/$PARQUET_REL" META-INF/MANIFEST.MF
        grep -q 'Implementation-Version: 1.18.1' META-INF/MANIFEST.MF
    )
    rm -rf "$VERIFY_PARQUET"
    (cd "$WAR_WORK" && jar uf "$WAR_PATH" "$PARQUET_REL")
    jar tf "$WAR_PATH" | grep -q 'BOOT-INF/lib/parquet-jackson-'
fi

OLD_BCPROV="$(find "$WAR_WORK/BOOT-INF/lib" -maxdepth 1 -type f -name 'bcprov-jdk18on-*.jar' 2>/dev/null | head -1 || true)"
if [ -n "$OLD_BCPROV" ]; then
    OLD_BCPROV_REL="${OLD_BCPROV#"$WAR_WORK/"}"
    zip -d "$WAR_PATH" "$OLD_BCPROV_REL" >/dev/null
    install -D -m 0644 "$BCPROV_185" "$WAR_WORK/BOOT-INF/lib/bcprov-jdk18on-1.85.jar"
    (cd "$WAR_WORK" && jar uf "$WAR_PATH" BOOT-INF/lib/bcprov-jdk18on-1.85.jar)
    jar tf "$WAR_PATH" | grep -q 'BOOT-INF/lib/bcprov-jdk18on-1.85.jar'
    ! jar tf "$WAR_PATH" | grep -q 'BOOT-INF/lib/bcprov-jdk18on-1.84.jar'
fi

VERIFY_MANIFEST="$(mktemp -d)"
(
    cd "$VERIFY_MANIFEST"
    jar xf "$WAR_PATH" META-INF/MANIFEST.MF
    grep -q 'Spring-Boot-Version:' META-INF/MANIFEST.MF
)
rm -rf "$VERIFY_MANIFEST"
