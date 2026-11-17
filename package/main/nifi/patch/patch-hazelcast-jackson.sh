#!/bin/bash
# Patch shaded Jackson copies inside hazelcast-*.jar.
#
# Hazelcast 5.7.0 embeds jackson-core/databind 2.21.2 and tools.jackson 3.1.2
# under com.hazelcast.shaded.*. Maven pins cannot reach those copies inside NiFi
# NAR bundles, so relocate fixed jackson JAR contents after the distribution is
# extracted. Fixes GHSA-r7wm-3cxj-wff9, CVE-2026-54512, and CVE-2026-54513.
set -euo pipefail

HZ_JAR="${1:?usage: patch-hazelcast-jackson.sh <hazelcast.jar> <patch-deps-dir>}"
PATCH_DIR="${2:?usage: patch-hazelcast-jackson.sh <hazelcast.jar> <patch-deps-dir>}"

HZ_JAR="$(readlink -f "$HZ_JAR")"
PATCH_DIR="$(readlink -f "$PATCH_DIR")"

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

HZ_WORK="$(mktemp -d)"
trap 'rm -rf "$HZ_WORK"' EXIT

cd "$HZ_WORK"
jar xf "$HZ_JAR"

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

write_pom_properties com.fasterxml.jackson.core jackson-core 2.21.7
write_pom_properties com.fasterxml.jackson.core jackson-databind 2.21.7
write_pom_properties tools.jackson.core jackson-core 3.1.7
write_pom_properties tools.jackson.core jackson-databind 3.1.7

test -f com/hazelcast/shaded/com/fasterxml/jackson/core/JsonFactory.class
test -f com/hazelcast/shaded/tools/jackson/databind/ObjectMapper.class

rm -f "$HZ_JAR"
jar cf "$HZ_JAR" .

jar tf "$HZ_JAR" | grep -q 'com/hazelcast/shaded/com/fasterxml/jackson/core/JsonFactory.class'
jar tf "$HZ_JAR" | grep -q 'com/hazelcast/shaded/tools/jackson/databind/ObjectMapper.class'

VERIFY_WORK="$(mktemp -d)"
(
    cd "$VERIFY_WORK"
    jar xf "$HZ_JAR" \
        META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties \
        META-INF/maven/tools.jackson.core/jackson-databind/pom.properties
    grep -q 'version=2.21.7' META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties
    grep -q 'version=3.1.7' META-INF/maven/tools.jackson.core/jackson-databind/pom.properties
)
rm -rf "$VERIFY_WORK"
