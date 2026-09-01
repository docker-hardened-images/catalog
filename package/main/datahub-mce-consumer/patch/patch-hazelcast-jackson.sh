#!/bin/bash
# Patch shaded Jackson copies inside any BOOT-INF/lib jar that embeds
# com.hazelcast.shaded.* jackson (hazelcast-*.jar, auth-api, etc.) in a Spring Boot
# fat jar (war.war or mce-consumer-job.jar).
#
# DataHub 1.5+ ships Hazelcast 5.7.0 with shaded jackson-core/databind 2.21.2 and
# tools.jackson 3.1.2. Gradle resolutionStrategy cannot reach those copies, so we
# relocate fixed jackson JAR contents into com.hazelcast.shaded.* after the fat jar
# is built. Fixes GHSA-r7wm-3cxj-wff9, CVE-2026-54512, CVE-2026-54513, and the
# shaded copies implicated by CVE-2026-54515 and CVE-2026-68497.
set -euo pipefail

WAR_PATH="${1:?usage: patch-hazelcast-jackson.sh <war.war>}"
PATCH_DIR="${2:?usage: patch-hazelcast-jackson.sh <war.war> <patch-deps-dir>}"

JACKSON_CORE_2="${PATCH_DIR}/jackson-core-2.21.6.jar"
JACKSON_DATABIND_2="${PATCH_DIR}/jackson-databind-2.21.6.jar"
JACKSON_CORE_3="${PATCH_DIR}/tools-jackson-core-3.1.6.jar"
JACKSON_DATABIND_3="${PATCH_DIR}/tools-jackson-databind-3.1.6.jar"

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

embedded_jars=()
for lib in BOOT-INF/lib/hazelcast-[0-9]*.jar BOOT-INF/lib/auth-api*.jar; do
    [ -f "$lib" ] || continue
    embedded_jars+=("$lib")
done

if [ "${#embedded_jars[@]}" -eq 0 ]; then
    echo "no embedded jars with shaded jackson in $WAR_PATH" >&2
    exit 1
fi

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

patch_embedded_jar() {
    local embedded_jar="$1"
    local hz_work
    hz_work="$(mktemp -d)"

  (
        cd "$hz_work"
        jar xf "$WAR_WORK/$embedded_jar"

        relocate_tree "$JACKSON_CORE_2" com/fasterxml/jackson/core com/hazelcast/shaded/com/fasterxml/jackson/core
        relocate_tree "$JACKSON_DATABIND_2" com/fasterxml/jackson/databind com/hazelcast/shaded/com/fasterxml/jackson/databind
        relocate_tree "$JACKSON_CORE_3" tools/jackson/core com/hazelcast/shaded/tools/jackson/core
        relocate_tree "$JACKSON_DATABIND_3" tools/jackson/databind com/hazelcast/shaded/tools/jackson/databind

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

        write_pom_properties com.fasterxml.jackson.core jackson-core 2.21.6
        write_pom_properties com.fasterxml.jackson.core jackson-databind 2.21.6
        write_pom_properties tools.jackson.core jackson-core 3.1.6
        write_pom_properties tools.jackson.core jackson-databind 3.1.6

        # Scout indexes pom.xml before pom.properties; drop stale shaded metadata.
        rm -f \
          META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.xml \
          META-INF/maven/com.fasterxml.jackson.core/jackson-databind/pom.xml \
          META-INF/maven/tools.jackson.core/jackson-core/pom.xml \
          META-INF/maven/tools.jackson.core/jackson-databind/pom.xml \
          META-INF/maven/com.hazelcast/hazelcast/pom.xml

        rm -f "$WAR_WORK/$embedded_jar"
        jar cf "$WAR_WORK/$embedded_jar" .

        jar tf "$WAR_WORK/$embedded_jar" | grep -q 'com/hazelcast/shaded/com/fasterxml/jackson/core/JsonFactory.class'
        jar tf "$WAR_WORK/$embedded_jar" | grep -q 'com/hazelcast/shaded/tools/jackson/databind/ObjectMapper.class'

        VERIFY_WORK="$(mktemp -d)"
        (
            cd "$VERIFY_WORK"
            jar xf "$WAR_WORK/$embedded_jar" \
                META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties \
                META-INF/maven/com.fasterxml.jackson.core/jackson-databind/pom.properties \
                META-INF/maven/tools.jackson.core/jackson-databind/pom.properties
            grep -q 'version=2.21.6' META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties
            grep -q 'version=2.21.6' META-INF/maven/com.fasterxml.jackson.core/jackson-databind/pom.properties
            grep -q 'version=3.1.6' META-INF/maven/tools.jackson.core/jackson-databind/pom.properties
        )
        rm -rf "$VERIFY_WORK"
    )

    rm -rf "$hz_work"

    # Update only the patched embedded jar. Repackaging the whole fat jar with jar cf
    # replaces META-INF/MANIFEST.MF with a minimal manifest and drops
    # Spring-Boot-Version (see TestWarManifest).
    (cd "$WAR_WORK" && jar uf "$WAR_PATH" "$embedded_jar")
}

for embedded_jar in "${embedded_jars[@]}"; do
    patch_embedded_jar "$embedded_jar"
done

VERIFY_MANIFEST="$(mktemp -d)"
(
    cd "$VERIFY_MANIFEST"
    jar xf "$WAR_PATH" META-INF/MANIFEST.MF
    grep -q 'Spring-Boot-Version:' META-INF/MANIFEST.MF
)
rm -rf "$VERIFY_MANIFEST"
