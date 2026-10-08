#!/bin/bash
# Patch shaded Jackson copies inside hazelcast-*.jar and auth-api-*.jar embedded in
# war.war, and replace loose jackson-* JARs under BOOT-INF/lib.
#
# DataHub ships Hazelcast 5.7.0 with shaded jackson 2.x/3.x copies Gradle cannot
# reach. auth-api may also bundle jackson classes. Loose jackson-core/databind JARs
# can remain on an older patch line despite resolutionStrategy, so we replace them
# with staged 2.21.7 artifacts after the WAR is built.
set -euo pipefail

WAR_PATH="${1:?usage: patch-hazelcast-jackson.sh <war.war>}"
PATCH_DIR="${2:?usage: patch-hazelcast-jackson.sh <war.war> <patch-deps-dir>}"

JACKSON_CORE_2="${PATCH_DIR}/jackson-core-2.21.7.jar"
JACKSON_DATABIND_2="${PATCH_DIR}/jackson-databind-2.21.7.jar"
JACKSON_CORE_3="${PATCH_DIR}/tools-jackson-core-3.1.7.jar"
JACKSON_DATABIND_3="${PATCH_DIR}/tools-jackson-databind-3.1.7.jar"

for jar in "$JACKSON_CORE_2" "$JACKSON_DATABIND_2" "$JACKSON_CORE_3" "$JACKSON_DATABIND_3"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

WAR_WORK="$(mktemp -d)"
trap 'rm -rf "$WAR_WORK"' EXIT

cd "$WAR_WORK"
jar xf "$WAR_PATH"

for old in BOOT-INF/lib/jackson-core-*.jar BOOT-INF/lib/jackson-databind-*.jar; do
    if [ -f "$old" ]; then
        zip -d "$WAR_PATH" "$old" >/dev/null
        rm -f "$old"
    fi
done

cp "$JACKSON_CORE_2" BOOT-INF/lib/jackson-core-2.21.7.jar
cp "$JACKSON_DATABIND_2" BOOT-INF/lib/jackson-databind-2.21.7.jar

relocate_tree() {
    local srcjar="$1"
    local srcsub="$2"
    local destsub="$3"
    local tmp
    tmp="$(mktemp -d)"

    (cd "$tmp" && jar xf "$srcjar")

    rm -rf "$destsub"
    find META-INF/versions -type d -path "*/${destsub}" -prune -exec rm -rf {} + 2>/dev/null || true

    mkdir -p "$(dirname "$destsub")"
    cp -a "$tmp/$srcsub" "$destsub"

    for verpath in "$tmp"/META-INF/versions/*/; do
        [ -d "$verpath" ] || continue
        ver="$(basename "$verpath")"
        if [ -d "$tmp/META-INF/versions/$ver/$srcsub" ]; then
            mkdir -p "META-INF/versions/$ver/$(dirname "$destsub")"
            cp -a "$tmp/META-INF/versions/$ver/$srcsub" "META-INF/versions/$ver/$destsub"
        fi
    done

    rm -rf "$tmp"
}

write_pom_properties() {
    local group="$1"
    local artifact="$2"
    local version="$3"
    mkdir -p "META-INF/maven/${group}/${artifact}"
    cat >"META-INF/maven/${group}/${artifact}/pom.properties" <<EOF
artifactId=${artifact}
groupId=${group}
version=${version}
EOF
}

patch_embedded_jackson() {
    local lib_jar="$1"
    local jar_work jar_listing
    jar_work="$(mktemp -d)"
    jar_listing="$(mktemp)"

    jar tf "$WAR_WORK/$lib_jar" >"$jar_listing"

    cd "$jar_work"
    jar xf "$WAR_WORK/$lib_jar"

    if grep -q 'com/hazelcast/shaded/com/fasterxml/jackson/core/' "$jar_listing"; then
        relocate_tree "$JACKSON_CORE_2" com/fasterxml/jackson/core com/hazelcast/shaded/com/fasterxml/jackson/core
        relocate_tree "$JACKSON_DATABIND_2" com/fasterxml/jackson/databind com/hazelcast/shaded/com/fasterxml/jackson/databind
        relocate_tree "$JACKSON_CORE_3" tools/jackson/core com/hazelcast/shaded/tools/jackson/core
        relocate_tree "$JACKSON_DATABIND_3" tools/jackson/databind com/hazelcast/shaded/tools/jackson/databind
        write_pom_properties com.fasterxml.jackson.core jackson-core 2.21.7
        write_pom_properties com.fasterxml.jackson.core jackson-databind 2.21.7
        write_pom_properties tools.jackson.core jackson-core 3.1.7
        write_pom_properties tools.jackson.core jackson-databind 3.1.7
    fi

    if grep -q '^com/fasterxml/jackson/core/' "$jar_listing"; then
        relocate_tree "$JACKSON_CORE_2" com/fasterxml/jackson/core com/fasterxml/jackson/core
        relocate_tree "$JACKSON_DATABIND_2" com/fasterxml/jackson/databind com/fasterxml/jackson/databind
        write_pom_properties com.fasterxml.jackson.core jackson-core 2.21.7
        write_pom_properties com.fasterxml.jackson.core jackson-databind 2.21.7
    fi

    if grep -q '^tools/jackson/core/' "$jar_listing"; then
        relocate_tree "$JACKSON_CORE_3" tools/jackson/core tools/jackson/core
        relocate_tree "$JACKSON_DATABIND_3" tools/jackson/databind tools/jackson/databind
        write_pom_properties tools.jackson.core jackson-core 3.1.7
        write_pom_properties tools.jackson.core jackson-databind 3.1.7
    fi

    rm -f "$WAR_WORK/$lib_jar"
    jar cf "$WAR_WORK/$lib_jar" .
    rm -rf "$jar_work" "$jar_listing"
    cd "$WAR_WORK"
}

for lib_jar in BOOT-INF/lib/hazelcast-[0-9]*.jar BOOT-INF/lib/auth-api-*.jar; do
    [ -f "$lib_jar" ] || continue
    patch_embedded_jackson "$lib_jar"
done

HZ_JAR="$(find BOOT-INF/lib -maxdepth 1 -type f -name 'hazelcast-[0-9]*.jar' | sort | head -1)"
if [ -n "$HZ_JAR" ]; then
    jar tf "$HZ_JAR" | grep -q 'com/hazelcast/shaded/com/fasterxml/jackson/core/JsonFactory.class'
    jar tf "$HZ_JAR" | grep -q 'com/hazelcast/shaded/tools/jackson/databind/ObjectMapper.class'

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
fi

# Update only patched entries. Repackaging the whole WAR with jar cf replaces
# META-INF/MANIFEST.MF with a minimal manifest and drops Spring-Boot-Version.
(
    cd "$WAR_WORK"
    jar uf "$WAR_PATH" \
        BOOT-INF/lib/jackson-core-2.21.7.jar \
        BOOT-INF/lib/jackson-databind-2.21.7.jar
    for lib_jar in BOOT-INF/lib/hazelcast-[0-9]*.jar BOOT-INF/lib/auth-api-*.jar; do
        [ -f "$lib_jar" ] || continue
        jar uf "$WAR_PATH" "$lib_jar"
    done
)

VERIFY_MANIFEST="$(mktemp -d)"
(
    cd "$VERIFY_MANIFEST"
    jar xf "$WAR_PATH" META-INF/MANIFEST.MF
    grep -q 'Spring-Boot-Version:' META-INF/MANIFEST.MF
)
rm -rf "$VERIFY_MANIFEST"
