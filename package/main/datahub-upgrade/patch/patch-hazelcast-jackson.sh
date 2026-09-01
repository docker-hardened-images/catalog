#!/bin/bash
# Patch shaded Jackson copies inside hazelcast-*.jar embedded in war.war.
#
# DataHub 1.6 ships Hazelcast 5.7.0 with shaded jackson-core/databind 2.21.2 and
# tools.jackson 3.1.2. Gradle resolutionStrategy cannot reach those copies, so we
# relocate fixed jackson JAR contents into com.hazelcast.shaded.* after the WAR
# is built. Fixes GHSA-r7wm-3cxj-wff9, CVE-2026-54512, CVE-2026-54513,
# CVE-2026-54515, and CVE-2026-68497.
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
HZ_WORK="$(mktemp -d)"
trap 'rm -rf "$WAR_WORK" "$HZ_WORK"' EXIT

cd "$WAR_WORK"
jar xf "$WAR_PATH"

# Match hazelcast-<version>.jar only; hazelcast-spring-*.jar also matches hazelcast-*.
HZ_JAR="$(find BOOT-INF/lib -maxdepth 1 -type f -name 'hazelcast-[0-9]*.jar' | sort | head -1)"
if [ -z "$HZ_JAR" ]; then
    echo "no hazelcast jar in $WAR_PATH" >&2
    exit 1
fi

cd "$HZ_WORK"
jar xf "$WAR_WORK/$HZ_JAR"

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

rm -f "$WAR_WORK/$HZ_JAR"
jar cf "$WAR_WORK/$HZ_JAR" .

jar tf "$WAR_WORK/$HZ_JAR" | grep -q 'com/hazelcast/shaded/com/fasterxml/jackson/core/JsonFactory.class'
jar tf "$WAR_WORK/$HZ_JAR" | grep -q 'com/hazelcast/shaded/tools/jackson/databind/ObjectMapper.class'

VERIFY_WORK="$(mktemp -d)"
(
    cd "$VERIFY_WORK"
    jar xf "$WAR_WORK/$HZ_JAR" \
        META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties \
        META-INF/maven/com.fasterxml.jackson.core/jackson-databind/pom.properties \
        META-INF/maven/tools.jackson.core/jackson-databind/pom.properties
    grep -q 'version=2.21.6' META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties
    grep -q 'version=2.21.6' META-INF/maven/com.fasterxml.jackson.core/jackson-databind/pom.properties
    grep -q 'version=3.1.6' META-INF/maven/tools.jackson.core/jackson-databind/pom.properties
)
rm -rf "$VERIFY_WORK"

# Update only the patched hazelcast jar. Repackaging the whole WAR with jar cf
# replaces META-INF/MANIFEST.MF with a minimal manifest and drops
# Spring-Boot-Version (see TestWarManifest).
(cd "$WAR_WORK" && jar uf "$WAR_PATH" "$HZ_JAR")

VERIFY_MANIFEST="$(mktemp -d)"
(
    cd "$VERIFY_MANIFEST"
    jar xf "$WAR_PATH" META-INF/MANIFEST.MF
    grep -q 'Spring-Boot-Version:' META-INF/MANIFEST.MF
)
rm -rf "$VERIFY_MANIFEST"
