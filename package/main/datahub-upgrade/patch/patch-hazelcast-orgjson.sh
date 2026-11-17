#!/bin/bash
# Replace the org.json copy shaded inside BOOT-INF/lib/hazelcast-<version>.jar
# (nested in the datahub-upgrade fat jar) with org.json 20260719, relocated by
# jarjar to the same com/hazelcast/shaded/org/json package Hazelcast already uses.
# Gradle pins cannot reach this copy, so the scanner reports it from the
# embedded META-INF/maven/org.json/json metadata (20250107 before this patch).
# The metadata is taken from the 20260719 jar so it matches the bytes shipped.
# Runs after patch-hazelcast-jackson.sh, which also rewrites the same nested jar.
set -euo pipefail

FAT_JAR="${1:?usage: patch-hazelcast-orgjson.sh <datahub-upgrade.jar> <patch-deps-dir>}"
PATCH_DIR="${2:?usage: patch-hazelcast-orgjson.sh <datahub-upgrade.jar> <patch-deps-dir>}"

ORGJSON_VERSION="20260719"
ORGJSON_JAR="${PATCH_DIR}/json-${ORGJSON_VERSION}.jar"
JARJAR_JAR="${PATCH_DIR}/jarjar-assembly-1.14.1.jar"
SHADED_DIR="com/hazelcast/shaded/org/json"

for jar in "$ORGJSON_JAR" "$JARJAR_JAR" "$FAT_JAR"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Match hazelcast-<version>.jar only; hazelcast-spring-*.jar also matches hazelcast-*.
HZ_ENTRY="$(jar tf "$FAT_JAR" | grep -E '^BOOT-INF/lib/hazelcast-[0-9][^/]*\.jar$' | sort | head -1 || true)"
if [ -z "$HZ_ENTRY" ]; then
    echo "no hazelcast-<version>.jar in ${FAT_JAR}" >&2
    exit 1
fi
(cd "$WORK" && jar xf "$FAT_JAR" "$HZ_ENTRY")
HZ_JAR="${WORK}/${HZ_ENTRY}"

cat >"${WORK}/rules.txt" <<'EOF'
rule org.json.** com.hazelcast.shaded.org.json.@1
EOF

java -jar "$JARJAR_JAR" process "${WORK}/rules.txt" "$ORGJSON_JAR" "${WORK}/json-relocated.jar"

mkdir -p "${WORK}/hz" "${WORK}/relocated" "${WORK}/orgjson"
(cd "${WORK}/hz" && jar xf "$HZ_JAR")
(cd "${WORK}/relocated" && jar xf "${WORK}/json-relocated.jar")
(cd "${WORK}/orgjson" && jar xf "$ORGJSON_JAR")

if [ ! -d "${WORK}/hz/${SHADED_DIR}" ]; then
    echo "hazelcast jar has no ${SHADED_DIR}; refusing to guess the layout" >&2
    exit 1
fi
if [ ! -d "${WORK}/relocated/${SHADED_DIR}" ]; then
    echo "relocated org.json has no ${SHADED_DIR}" >&2
    exit 1
fi

(cd "${WORK}/hz" && find "$SHADED_DIR" -name '*.class' | sort) >"${WORK}/hz-classes.txt"
(cd "${WORK}/relocated" && find "$SHADED_DIR" -name '*.class' | sort) >"${WORK}/new-classes.txt"
# The build image has no diff(1); grep -vxFf compares the two sets both ways.
if [ -n "$(grep -vxFf "${WORK}/hz-classes.txt" "${WORK}/new-classes.txt")" ] \
    || [ -n "$(grep -vxFf "${WORK}/new-classes.txt" "${WORK}/hz-classes.txt")" ]; then
    echo "shaded org.json class set changed; review before replacing" >&2
    exit 1
fi

rm -rf "${WORK}/hz/${SHADED_DIR}"
cp -a "${WORK}/relocated/${SHADED_DIR}" "${WORK}/hz/${SHADED_DIR}"

META="${WORK}/hz/META-INF/maven/org.json/json"
mkdir -p "$META"
cp -a "${WORK}/orgjson/META-INF/maven/org.json/json/pom.properties" "${META}/pom.properties"
cp -a "${WORK}/orgjson/META-INF/maven/org.json/json/pom.xml" "${META}/pom.xml"

if ! grep -q "^version=${ORGJSON_VERSION}\$" "${META}/pom.properties"; then
    echo "embedded org.json pom.properties is not ${ORGJSON_VERSION}" >&2
    cat "${META}/pom.properties" >&2
    exit 1
fi
if grep -q '20250107' "${META}/pom.properties" "${META}/pom.xml"; then
    echo "embedded org.json metadata still names 20250107" >&2
    exit 1
fi

(cd "${WORK}/hz" && jar cMf "$HZ_JAR" .)

jar tf "$HZ_JAR" >"${WORK}/check.txt"
grep -qx "${SHADED_DIR}/JSONObject.class" "${WORK}/check.txt"
grep -qx "${SHADED_DIR}/JSONArray.class" "${WORK}/check.txt"
grep -qx "META-INF/maven/org.json/json/pom.properties" "${WORK}/check.txt"

javap -classpath "$HZ_JAR" "com.hazelcast.shaded.org.json.JSONObject" >/dev/null

(cd "$WORK" && jar --update --no-compress --file "$FAT_JAR" "$HZ_ENTRY")

# Spring Boot reads nested libraries without inflating them. Run last so this
# also checks the nested JARs written by patch-hazelcast-jackson.sh.
STORED_CHECK="$WORK/CheckStored.java"
cat >"$STORED_CHECK" <<'JAVA'
import java.util.Enumeration;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public class CheckStored {
    public static void main(String[] args) throws Exception {
        int bad = 0;
        int n = 0;
        try (ZipFile z = new ZipFile(args[0])) {
            for (Enumeration<? extends ZipEntry> e = z.entries(); e.hasMoreElements();) {
                ZipEntry ze = e.nextElement();
                String name = ze.getName();
                if (name.startsWith("BOOT-INF/lib/") && name.endsWith(".jar")) {
                    n++;
                    if (ze.getMethod() != ZipEntry.STORED) {
                        System.err.println("nested jar not STORED: " + name);
                        bad++;
                    }
                }
            }
        }
        if (n == 0) {
            System.err.println("no BOOT-INF/lib/*.jar entries in the fat JAR");
            System.exit(1);
        }
        System.exit(bad == 0 ? 0 : 1);
    }
}
JAVA
java "$STORED_CHECK" "$FAT_JAR"

echo "replaced shaded org.json in ${HZ_ENTRY} (nested in ${FAT_JAR}) with ${ORGJSON_VERSION}"
