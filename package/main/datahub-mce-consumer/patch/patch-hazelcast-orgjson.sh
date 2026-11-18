#!/bin/bash
# Patch the org.json copy shaded inside hazelcast-*.jar embedded in the Spring
# Boot jar (CVE-2026-59171).
#
# hazelcast 5.7.0 embeds org.json 20250107 under com/hazelcast/shaded/org/json.
# Gradle resolutionStrategy cannot replace those bytes. jarjar relocates the
# org.json 20260814 jar (same release line as the Gradle force; fixed in 20260719)
# into the same shaded namespace, and the embedded Maven metadata is replaced so
# the SBOM reports the fixed version. org.json has no external dependencies, so
# the relocated tree is self-contained.
set -euo pipefail

BOOT_JAR="${1:?usage: patch-hazelcast-orgjson.sh <boot.jar> <patch-deps-dir>}"
PATCH_DIR="${2:?usage: patch-hazelcast-orgjson.sh <boot.jar> <patch-deps-dir>}"

JSON_VERSION=20260814
JSON_JAR="${PATCH_DIR}/json-${JSON_VERSION}.jar"
JARJAR_VERSION=1.14.1
JARJAR_JAR="${PATCH_DIR}/jarjar-assembly-${JARJAR_VERSION}.jar"
SHADED_PREFIX=com/hazelcast/shaded/org/json
META_DIR=META-INF/maven/org.json/json

for jar in "$JSON_JAR" "$JARJAR_JAR"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

BOOT_WORK="$(mktemp -d)"
HZ_WORK="$(mktemp -d)"
JARJAR_WORK="$(mktemp -d)"
META_WORK="$(mktemp -d)"
trap 'rm -rf "$BOOT_WORK" "$HZ_WORK" "$JARJAR_WORK" "$META_WORK"' EXIT

cd "$BOOT_WORK"
jar xf "$BOOT_JAR"

# Match hazelcast-<version>.jar only; hazelcast-spring-*.jar also matches hazelcast-*.
HZ_JAR="$(find BOOT-INF/lib -maxdepth 1 -type f -name 'hazelcast-[0-9]*.jar' | sort | head -1)"
if [ -z "$HZ_JAR" ]; then
    echo "no hazelcast jar in $BOOT_JAR" >&2
    exit 1
fi

cd "$HZ_WORK"
jar xf "$BOOT_WORK/$HZ_JAR"

# Drop the embedded 20250107 tree, including any multi-release copies.
rm -rf "$SHADED_PREFIX"
if [ -d META-INF/versions ]; then
    find META-INF/versions -type d -path "*/${SHADED_PREFIX}" -prune -exec rm -rf {} +
fi

RULES="$(mktemp)"
echo "rule org.json.** com.hazelcast.shaded.org.json.@1" >"$RULES"
java -jar "$JARJAR_JAR" process "$RULES" "$JSON_JAR" "$JARJAR_WORK/relocated.jar"
rm -f "$RULES"

(cd "$JARJAR_WORK" && jar xf relocated.jar)
if [ ! -d "$JARJAR_WORK/$SHADED_PREFIX" ]; then
    echo "jarjar output missing $SHADED_PREFIX from $JSON_JAR" >&2
    exit 1
fi
mkdir -p "$SHADED_PREFIX"
cp -a "$JARJAR_WORK/$SHADED_PREFIX/." "$SHADED_PREFIX/"

# Replace the embedded org.json 20250107 Maven metadata with the fixed artifact's.
(cd "$META_WORK" && jar xf "$JSON_JAR" "${META_DIR}/pom.xml" "${META_DIR}/pom.properties")
if [ ! -f "$META_WORK/${META_DIR}/pom.xml" ] || [ ! -f "$META_WORK/${META_DIR}/pom.properties" ]; then
    echo "fixed artifact missing maven metadata: $JSON_JAR" >&2
    exit 1
fi
mkdir -p "$META_DIR"
cp -a "$META_WORK/${META_DIR}/pom.xml" "$META_WORK/${META_DIR}/pom.properties" "$META_DIR/"

grep -q "version=${JSON_VERSION}" "$META_DIR/pom.properties"
grep -q "<version>${JSON_VERSION}</version>" "$META_DIR/pom.xml"
if grep -q '20250107' "$META_DIR/pom.properties" "$META_DIR/pom.xml"; then
    echo "embedded org.json maven metadata still names 20250107" >&2
    exit 1
fi

rm -f "$BOOT_WORK/$HZ_JAR"
jar cf "$BOOT_WORK/$HZ_JAR" .

jar tf "$BOOT_WORK/$HZ_JAR" | grep -q "${SHADED_PREFIX}/JSONObject.class"
if jar tf "$BOOT_WORK/$HZ_JAR" | grep -q '^org/json/'; then
    echo "unshaded org/json classes must not remain in hazelcast jar" >&2
    exit 1
fi

VERIFY_CLASS="$(mktemp -d)"
(
    cd "$VERIFY_CLASS"
    jar xf "$BOOT_WORK/$HZ_JAR" "${SHADED_PREFIX}/JSONObject.class"
    javap -verbose -classpath . com.hazelcast.shaded.org.json.JSONObject \
        | grep -q 'this_class:.*com/hazelcast/shaded/org/json/JSONObject'
    if javap -v -classpath . com.hazelcast.shaded.org.json.JSONObject \
        | grep -E 'org/json/' | grep -v 'com/hazelcast/shaded/org/json/' | grep -q .; then
        echo "relocated JSONObject still references unshaded org/json" >&2
        exit 1
    fi
)
rm -rf "$VERIFY_CLASS"

(cd "$BOOT_WORK" && jar uf "$BOOT_JAR" "$HZ_JAR")

VERIFY_MANIFEST="$(mktemp -d)"
(
    cd "$VERIFY_MANIFEST"
    jar xf "$BOOT_JAR" META-INF/MANIFEST.MF
    grep -q 'Spring-Boot-Version:' META-INF/MANIFEST.MF
)
rm -rf "$VERIFY_MANIFEST"
