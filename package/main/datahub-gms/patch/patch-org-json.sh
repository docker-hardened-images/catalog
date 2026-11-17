#!/bin/bash
# Replace every org.json copy inside war.war with org.json 20260719 (CVE-2026-59171).
#
# Three copies ship in the WAR and Gradle cannot reach the embedded two:
#   - BOOT-INF/lib/json-20231013.jar: standalone JAR, replaced by json-20260719.jar.
#   - BOOT-INF/lib/auth-api-*.jar: bundles org/json 20231013 classes; that tree is replaced
#     with the org/json 20260719 classes under their own names.
#   - BOOT-INF/lib/hazelcast-*.jar: bundles com/hazelcast/shaded/org/json (20250107); that
#     tree is replaced with the 20260719 classes relocated by jarjar to the shaded prefix.
#
# A class declares its own name in its bytecode, so copying org/json under the shaded path
# alone fails at load with NoClassDefFoundError: wrong name. The relocation follows
# patch-shaded-guava.sh.
set -euo pipefail

JSON_VERSION="20260719"
SHADED_PREFIX="com/hazelcast/shaded/org/json"
JARJAR_VERSION=1.7.2

WAR_PATH="${1:?usage: patch-org-json.sh <war.war> <patch-deps-dir>}"
PATCH_DIR="${2:?usage: patch-org-json.sh <war.war> <patch-deps-dir>}"
PATCH_DIR="$(cd "$PATCH_DIR" && pwd)"
JSON_JAR="${PATCH_DIR}/json-${JSON_VERSION}.jar"
JARJAR_CP="${PATCH_DIR}/jarjar-${JARJAR_VERSION}.jar:${PATCH_DIR}/asm-7.0.jar:${PATCH_DIR}/asm-commons-7.0.jar"

for jar in "$JSON_JAR" "${PATCH_DIR}/jarjar-${JARJAR_VERSION}.jar" \
    "${PATCH_DIR}/asm-7.0.jar" "${PATCH_DIR}/asm-commons-7.0.jar"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

WAR_PATH="$(cd "$(dirname "$WAR_PATH")" && pwd)/$(basename "$WAR_PATH")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

JSON_WORK="$WORK/json"
mkdir -p "$JSON_WORK"
(cd "$JSON_WORK" && jar xf "$JSON_JAR")

WAR_WORK="$WORK/war"
mkdir -p "$WAR_WORK"
(cd "$WAR_WORK" && jar xf "$WAR_PATH")

# relocate_json <out-dir>
# Relocates the org.json 20260719 classes to ${SHADED_PREFIX}. jarjar rewrites every
# org/json reference in the bytecode, so the relocated classes name themselves and each
# other under the shaded path.
relocate_json() {
    local out="$1"
    local rules
    local jarout

    rules="$(mktemp "$WORK/rules.XXXXXX")"
    jarout="$(mktemp -d "$WORK/relocated.XXXXXX")"
    echo "rule org.json.** com.hazelcast.shaded.org.json.@1" >"$rules"
    java -cp "$JARJAR_CP" org.pantsbuild.jarjar.Main process "$rules" "$JSON_JAR" "$jarout/relocated.jar"
    (cd "$out" && jar xf "$jarout/relocated.jar")
}

# verify_relocated_json <classes-root>
# Every class under ${SHADED_PREFIX} must declare its own shaded name as this_class and
# must not reference a plain org/json class.
verify_relocated_json() {
    local root="$1"
    local tree="$root/${SHADED_PREFIX}"
    local count=0
    local f
    local cls
    local this_line
    local refs

    if [ ! -f "$tree/JSONObject.class" ]; then
        echo "relocated org.json has no ${SHADED_PREFIX}/JSONObject.class" >&2
        return 1
    fi
    while IFS= read -r f; do
        cls="${f#"$root"/}"
        cls="${cls%.class}"
        this_line="$(javap -verbose "$f" | grep -F 'this_class:')"
        if [[ "$this_line" != *"// ${cls}" ]]; then
            echo "wrong this_class in $f: want ${cls}, got: ${this_line}" >&2
            return 1
        fi
        refs="$(javap -verbose "$f" | grep -E 'Utf8[[:space:]]+org/json/' || true)"
        if [ -n "$refs" ]; then
            echo "plain org/json reference left in $f" >&2
            return 1
        fi
        count=$((count + 1))
    done < <(find "$tree" -name '*.class' -type f)
    [ "$count" -gt 0 ]
}

RELOC_WORK="$WORK/relocated-classes"
mkdir -p "$RELOC_WORK"
relocate_json "$RELOC_WORK"
verify_relocated_json "$RELOC_WORK"

# install_tree <extracted-jar-dir> <dest-subpath> <classes-src-dir>
# Replaces <dest-subpath> with <classes-src-dir>, and the Maven metadata from the 20260719
# JAR so the SBOM reports the new version.
install_tree() {
    local dir="$1"
    local destsub="$2"
    local src="$3"

    rm -rf "$dir/$destsub"
    find "$dir/META-INF/versions" -type d -path "*/${destsub}" -prune -exec rm -rf {} + 2>/dev/null || true
    mkdir -p "$dir/$(dirname "$destsub")"
    cp -a "$src" "$dir/$destsub"

    rm -rf "$dir/META-INF/maven/org.json/json"
    mkdir -p "$dir/META-INF/maven/org.json/json"
    cp -a "$JSON_WORK/META-INF/maven/org.json/json/." "$dir/META-INF/maven/org.json/json/"
}

# patch_embedded <lib-jar-name> <dest-subpath> <classes-src-dir>
patch_embedded() {
    local lib_jar="$1"
    local destsub="$2"
    local src="$3"
    local jar_work

    jar_work="$(mktemp -d "$WORK/embedded.XXXXXX")"
    (cd "$jar_work" && jar xf "$WAR_WORK/$lib_jar")
    install_tree "$jar_work" "$destsub" "$src"

    rm -f "$WAR_WORK/$lib_jar"
    (cd "$jar_work" && jar cf "$WAR_WORK/$lib_jar" .)
}

cd "$WAR_WORK"

PATCHED=()

# 1. Standalone org.json JARs: drop every older copy and add the 20260719 JAR. The WAR must
#    carry one; a missing copy means this patch no longer matches the WAR.
standalone=(BOOT-INF/lib/json-[0-9]*.jar)
if [ ! -f "${standalone[0]}" ]; then
    echo "no standalone json-*.jar in $WAR_PATH" >&2
    exit 1
fi
for old in BOOT-INF/lib/json-[0-9]*.jar; do
    [ -f "$old" ] || continue
    zip -d "$WAR_PATH" "$old" >/dev/null
    rm -f "$old"
done
cp "$JSON_JAR" "BOOT-INF/lib/json-${JSON_VERSION}.jar"
PATCHED+=("BOOT-INF/lib/json-${JSON_VERSION}.jar")

# 2. Embedded copies inside hazelcast and auth-api. A jar in these globs is patched when it
#    carries an org.json tree; a jar without one (auth-api-*-lib.jar) is not a copy. The WAR must
#    still carry one shaded copy and one plain copy, or the patch has stopped matching the WAR.
SHADED_TARGETS=0
PLAIN_TARGETS=0
for lib_jar in BOOT-INF/lib/hazelcast-[0-9]*.jar BOOT-INF/lib/auth-api-*.jar; do
    [ -f "$lib_jar" ] || continue

    listing="$(mktemp "$WORK/listing.XXXXXX")"
    jar tf "$lib_jar" >"$listing"

    if grep -q "^${SHADED_PREFIX}/" "$listing"; then
        patch_embedded "$lib_jar" "$SHADED_PREFIX" "$RELOC_WORK/${SHADED_PREFIX}"
        PATCHED+=("$lib_jar")
        SHADED_TARGETS=$((SHADED_TARGETS + 1))
    elif grep -q '^org/json/' "$listing"; then
        patch_embedded "$lib_jar" org/json "$JSON_WORK/org/json"
        PATCHED+=("$lib_jar")
        PLAIN_TARGETS=$((PLAIN_TARGETS + 1))
    fi
    rm -f "$listing"
done
if [ "$SHADED_TARGETS" -lt 1 ]; then
    echo "no BOOT-INF/lib/hazelcast-*.jar with ${SHADED_PREFIX}/ classes in $WAR_PATH" >&2
    exit 1
fi
if [ "$PLAIN_TARGETS" -lt 1 ]; then
    echo "no BOOT-INF/lib/auth-api-*.jar with org/json/ classes in $WAR_PATH" >&2
    exit 1
fi

# 3. Verify: every patched JAR reports 20260719.
VERIFY_WORK="$(mktemp -d "$WORK/verify.XXXXXX")"
for lib_jar in "${PATCHED[@]}"; do
    (
        cd "$VERIFY_WORK"
        jar xf "$WAR_WORK/$lib_jar" META-INF/maven/org.json/json/pom.properties
        grep -q "version=${JSON_VERSION}" META-INF/maven/org.json/json/pom.properties
        rm -rf META-INF
    )
done
rm -rf "$VERIFY_WORK"

# 4. Write only the patched entries back into the WAR. Repacking the whole WAR would
#    drop the Spring Boot manifest entries, as noted in patch-hazelcast-jackson.sh. --no-compress
#    keeps the nested JARs STORED; Spring Boot's loader cannot read deflated nested JARs.
jar --update --no-compress --file "$WAR_PATH" "${PATCHED[@]}"

VERIFY_MANIFEST="$(mktemp -d "$WORK/manifest.XXXXXX")"
(
    cd "$VERIFY_MANIFEST"
    jar xf "$WAR_PATH" META-INF/MANIFEST.MF
    grep -q 'Spring-Boot-Version:' META-INF/MANIFEST.MF
)

# 5. Every nested library must be STORED. This runs last, so it covers the output of all three
#    patch scripts.
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
            System.err.println("no BOOT-INF/lib/*.jar entries in the WAR");
            System.exit(1);
        }
        System.exit(bad == 0 ? 0 : 1);
    }
}
JAVA
java "$STORED_CHECK" "$WAR_PATH"

# 6. Inspect every nested library as written, not only the patched ones. Each org/json tree
#    must match the expected tree and each org.json Maven metadata must report 20260719.
FINAL_WORK="$(mktemp -d "$WORK/final.XXXXXX")"
(cd "$FINAL_WORK" && jar xf "$WAR_PATH")

# list_files <listing-file> <prefix>: file entries under <prefix>/, sorted.
list_files() {
    awk -v p="$2/" 'index($0, p) == 1 && $0 !~ /\/$/' "$1" | sort
}

EXPECT_PLAIN="$WORK/expect-plain.txt"
EXPECT_SHADED="$WORK/expect-shaded.txt"
jar tf "$JSON_JAR" >"$WORK/json-listing.txt"
list_files "$WORK/json-listing.txt" org/json >"$EXPECT_PLAIN"
(cd "$RELOC_WORK" && find "$SHADED_PREFIX" -type f | sort) >"$EXPECT_SHADED"
if [ ! -s "$EXPECT_PLAIN" ] || [ ! -s "$EXPECT_SHADED" ]; then
    echo "expected org/json trees are empty" >&2
    exit 1
fi

NESTED_LIST="$WORK/nested-listing.txt"
for nested in "$FINAL_WORK"/BOOT-INF/lib/*.jar; do
    name="BOOT-INF/lib/$(basename "$nested")"
    case "$name" in
        BOOT-INF/lib/json-[0-9]*.jar)
            if [ "$name" != "BOOT-INF/lib/json-${JSON_VERSION}.jar" ]; then
                echo "unexpected standalone JSON jar: $name" >&2
                exit 1
            fi
            ;;
    esac

    jar tf "$nested" >"$NESTED_LIST"

    list_files "$NESTED_LIST" org/json >"$WORK/got-plain.txt"
    if [ -s "$WORK/got-plain.txt" ]; then
        case "$name" in
            "BOOT-INF/lib/json-${JSON_VERSION}.jar"|BOOT-INF/lib/auth-api-*.jar) ;;
            *)
                echo "unexpected org/json tree in $name" >&2
                exit 1
                ;;
        esac
        # Bash-only comparison: the build image has no cmp.
        if [ "$(<"$EXPECT_PLAIN")" != "$(<"$WORK/got-plain.txt")" ]; then
            echo "org/json tree in $name does not match json-${JSON_VERSION}.jar" >&2
            exit 1
        fi
    fi

    list_files "$NESTED_LIST" "$SHADED_PREFIX" >"$WORK/got-shaded.txt"
    if [ -s "$WORK/got-shaded.txt" ]; then
        case "$name" in
            BOOT-INF/lib/hazelcast-*.jar) ;;
            *)
                echo "unexpected ${SHADED_PREFIX}/ tree in $name" >&2
                exit 1
                ;;
        esac
        if [ "$(<"$EXPECT_SHADED")" != "$(<"$WORK/got-shaded.txt")" ]; then
            echo "${SHADED_PREFIX}/ tree in $name does not match the relocated 20260719 classes" >&2
            exit 1
        fi
    fi

    if grep -q '^META-INF/maven/org\.json/' "$NESTED_LIST"; then
        meta="$(mktemp -d "$WORK/meta.XXXXXX")"
        (cd "$meta" && jar xf "$nested")
        props_list="$(cd "$meta" && find META-INF/maven/org.json -name pom.properties | sort)"
        if [ -z "$props_list" ]; then
            echo "org.json Maven metadata in $name has no pom.properties" >&2
            exit 1
        fi
        while IFS= read -r props; do
            if ! grep -qx "version=${JSON_VERSION}" "$meta/$props"; then
                echo "org.json metadata in $name is not version=${JSON_VERSION}: $props" >&2
                exit 1
            fi
        done <<<"$props_list"
    fi
done
