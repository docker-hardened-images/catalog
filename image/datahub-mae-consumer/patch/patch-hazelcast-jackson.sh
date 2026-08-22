#!/bin/bash
# Patch shaded Jackson copies inside hazelcast-*.jar embedded in a Spring Boot fat jar.
#
# DataHub 1.6 ships Hazelcast 5.7.0 with shaded jackson-core/databind 2.21.2 and
# tools.jackson 3.1.2. Gradle resolutionStrategy cannot reach those copies, so we
# relocate fixed jackson JAR contents into com.hazelcast.shaded.* after the fat jar
# is built. Mirrors image/datahub-gms/patch/patch-hazelcast-jackson.sh.
set -euo pipefail

JAR_PATH="${1:?usage: patch-hazelcast-jackson.sh <fat.jar>}"
PATCH_DIR="${2:?usage: patch-hazelcast-jackson.sh <fat.jar> <patch-deps-dir>}"

JACKSON_CORE_2="${PATCH_DIR}/jackson-core-2.21.5.jar"
JACKSON_DATABIND_2="${PATCH_DIR}/jackson-databind-2.21.5.jar"
JACKSON_CORE_3="${PATCH_DIR}/tools-jackson-core-3.1.4.jar"
JACKSON_DATABIND_3="${PATCH_DIR}/tools-jackson-databind-3.1.5.jar"

for jar in "$JACKSON_CORE_2" "$JACKSON_DATABIND_2" "$JACKSON_CORE_3" "$JACKSON_DATABIND_3"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

JAR_WORK="$(mktemp -d)"
trap 'rm -rf "$JAR_WORK"' EXIT

cd "$JAR_WORK"
jar xf "$JAR_PATH"

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

patch_hazelcast_jar() {
    local hz_rel="$1"
    local hz_work
    hz_work="$(mktemp -d)"

    (cd "$hz_work" && jar xf "$JAR_WORK/$hz_rel")

    if [ ! -f "$hz_work/META-INF/maven/tools.jackson.core/jackson-core/pom.properties" ] \
        && [ ! -f "$hz_work/META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties" ]; then
        rm -rf "$hz_work"
        return 0
    fi

    (
        cd "$hz_work"
        relocate_tree "$JACKSON_CORE_2" com/fasterxml/jackson/core com/hazelcast/shaded/com/fasterxml/jackson/core
        relocate_tree "$JACKSON_DATABIND_2" com/fasterxml/jackson/databind com/hazelcast/shaded/com/fasterxml/jackson/databind
        relocate_tree "$JACKSON_CORE_3" tools/jackson/core com/hazelcast/shaded/tools/jackson/core
        relocate_tree "$JACKSON_DATABIND_3" tools/jackson/databind com/hazelcast/shaded/tools/jackson/databind

        write_pom_properties com.fasterxml.jackson.core jackson-core 2.21.5
        write_pom_properties com.fasterxml.jackson.core jackson-databind 2.21.5
        write_pom_properties tools.jackson.core jackson-core 3.1.4
        write_pom_properties tools.jackson.core jackson-databind 3.1.5

        rm -f "$JAR_WORK/$hz_rel"
        jar cf "$JAR_WORK/$hz_rel" .

        jar tf "$JAR_WORK/$hz_rel" | grep -q 'com/hazelcast/shaded/com/fasterxml/jackson/core/JsonFactory.class'
        jar tf "$JAR_WORK/$hz_rel" | grep -q 'com/hazelcast/shaded/tools/jackson/databind/ObjectMapper.class'

        VERIFY_WORK="$(mktemp -d)"
        (
            cd "$VERIFY_WORK"
            jar xf "$JAR_WORK/$hz_rel" \
                META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties \
                META-INF/maven/tools.jackson.core/jackson-databind/pom.properties
            grep -q 'version=2.21.5' META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties
            grep -q 'version=3.1.5' META-INF/maven/tools.jackson.core/jackson-databind/pom.properties
        )
        rm -rf "$VERIFY_WORK"
    )

    rm -rf "$hz_work"
}

mapfile -t hz_jars < <(find BOOT-INF/lib -maxdepth 1 -type f -name 'hazelcast*.jar' | sort)
if [ "${#hz_jars[@]}" -eq 0 ]; then
    echo "no hazelcast jar in $JAR_PATH" >&2
    exit 1
fi

for hz_rel in "${hz_jars[@]}"; do
    patch_hazelcast_jar "$hz_rel"
done

for hz_rel in "${hz_jars[@]}"; do
    (cd "$JAR_WORK" && jar uf "$JAR_PATH" "$hz_rel")
done

VERIFY_MANIFEST="$(mktemp -d)"
(
    cd "$VERIFY_MANIFEST"
    jar xf "$JAR_PATH" META-INF/MANIFEST.MF
    grep -q 'Spring-Boot-Version:' META-INF/MANIFEST.MF
)
rm -rf "$VERIFY_MANIFEST"
