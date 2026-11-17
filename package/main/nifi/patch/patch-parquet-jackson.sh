#!/bin/bash
# Patch shaded Jackson copies inside parquet-jackson-*.jar.
#
# parquet-jackson 1.17.1 embeds jackson-core/databind 2.21.3 under
# shaded/parquet/com/fasterxml/jackson/*. NiFi Maven pins cannot replace those
# shaded copies, so relocate fixed jackson JAR contents after extraction.
# Fixes GHSA-r7wm-3cxj-wff9, CVE-2026-54512, and CVE-2026-54513.
set -euo pipefail

PQ_JAR="${1:?usage: patch-parquet-jackson.sh <parquet-jackson.jar> <patch-deps-dir>}"
PATCH_DIR="${2:?usage: patch-parquet-jackson.sh <parquet-jackson.jar> <patch-deps-dir>}"

PQ_JAR="$(readlink -f "$PQ_JAR")"
PATCH_DIR="$(readlink -f "$PATCH_DIR")"

JACKSON_CORE_2="${PATCH_DIR}/jackson-core-2.21.7.jar"
JACKSON_DATABIND_2="${PATCH_DIR}/jackson-databind-2.21.7.jar"

for jar in "$JACKSON_CORE_2" "$JACKSON_DATABIND_2"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

PQ_WORK="$(mktemp -d)"
trap 'rm -rf "$PQ_WORK"' EXIT

cd "$PQ_WORK"
jar xf "$PQ_JAR"

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

relocate_tree "$JACKSON_CORE_2" com/fasterxml/jackson/core shaded/parquet/com/fasterxml/jackson/core
relocate_tree "$JACKSON_DATABIND_2" com/fasterxml/jackson/databind shaded/parquet/com/fasterxml/jackson/databind

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

test -f shaded/parquet/com/fasterxml/jackson/core/JsonFactory.class
test -f shaded/parquet/com/fasterxml/jackson/databind/ObjectMapper.class

rm -f "$PQ_JAR"
jar cf "$PQ_JAR" .

jar tf "$PQ_JAR" | grep -q 'shaded/parquet/com/fasterxml/jackson/core/JsonFactory.class'

VERIFY_WORK="$(mktemp -d)"
(
    cd "$VERIFY_WORK"
    jar xf "$PQ_JAR" \
        META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties \
        META-INF/maven/com.fasterxml.jackson.core/jackson-databind/pom.properties
    grep -q 'version=2.21.7' META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties
    grep -q 'version=2.21.7' META-INF/maven/com.fasterxml.jackson.core/jackson-databind/pom.properties
)
rm -rf "$VERIFY_WORK"
