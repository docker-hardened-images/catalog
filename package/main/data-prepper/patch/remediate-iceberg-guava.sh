#!/bin/bash
# Replace the Guava copy shaded inside iceberg-bundled-guava with Guava 33.7.2-jre.
# Iceberg 1.10.1 ships Guava 33.4.8-jre relocated under org/apache/iceberg/relocated
# (CVE-2026-102554). Gradle pins cannot reach those classes. No published
# iceberg-bundled-guava carries a fixed Guava yet: 1.10.2 is still 33.4.8-jre, 1.11.0
# is 33.6.0-jre, and 1.12.0 is 33.7.1-jre, which is still in the vulnerable range
# (<=33.7.1). This relocates Guava 33.7.2-jre and failureaccess 1.0.3 with the same
# prefix and rewrites the bundle's Maven metadata to match.
set -euo pipefail

JARS_DIR="${1:?usage: remediate-iceberg-guava.sh <jars-dir> <patch-deps-dir> <guava-version>}"
PATCH_DIR="${2:?usage: remediate-iceberg-guava.sh <jars-dir> <patch-deps-dir> <guava-version>}"
GUAVA_VERSION="${3:?usage: remediate-iceberg-guava.sh <jars-dir> <patch-deps-dir> <guava-version>}"

FAILUREACCESS_VERSION=1.0.3
RELOCATED_ROOT=org/apache/iceberg/relocated

GUAVA_JAR="${PATCH_DIR}/guava-${GUAVA_VERSION}.jar"
FAILUREACCESS_JAR="${PATCH_DIR}/failureaccess-${FAILUREACCESS_VERSION}.jar"
JARJAR_VERSION=1.14.1
JARJAR_JAR="${PATCH_DIR}/jarjar-assembly-${JARJAR_VERSION}.jar"

for jar in "$GUAVA_JAR" "$FAILUREACCESS_JAR" "$JARJAR_JAR"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

BUNDLE_JAR="$(find "${JARS_DIR}" -maxdepth 1 -name 'iceberg-bundled-guava-*.jar' -print -quit)"
if [ -z "$BUNDLE_JAR" ] || [ ! -f "$BUNDLE_JAR" ]; then
    echo "iceberg-bundled-guava jar not found under ${JARS_DIR}" >&2
    exit 1
fi

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
    (cd "$work" && jar cMf "$jarpath" .)
    rm -rf "$work"
}

# Relocate Guava and failureaccess into the bundle's own prefix. Output lands in
# $RELOCATED_TREE with the org/apache/iceberg/relocated/... layout only.
relocate_guava() {
    local rules
    rules="$(mktemp)"
    cat >"$rules" <<'EOF'
rule com.google.common.** org.apache.iceberg.relocated.com.google.common.@1
rule com.google.thirdparty.** org.apache.iceberg.relocated.com.google.thirdparty.@1
EOF

    RELOCATED_WORK="$(mktemp -d)"
    java -jar "$JARJAR_JAR" process "$rules" "$GUAVA_JAR" "$RELOCATED_WORK/guava.jar"
    java -jar "$JARJAR_JAR" process "$rules" "$FAILUREACCESS_JAR" "$RELOCATED_WORK/failureaccess.jar"
    rm -f "$rules"

    RELOCATED_TREE="$RELOCATED_WORK/tree"
    mkdir -p "$RELOCATED_TREE"
    (cd "$RELOCATED_TREE" && jar xf "$RELOCATED_WORK/guava.jar" && jar xf "$RELOCATED_WORK/failureaccess.jar")
    rm -rf "$RELOCATED_TREE/META-INF"
    # Keep only the relocated tree; the source jars' own META-INF is rewritten below.
    if [ -d "$RELOCATED_TREE/org" ]; then
        find "$RELOCATED_TREE" -mindepth 1 -maxdepth 1 ! -name org -exec rm -rf {} +
    fi
    if [ ! -d "$RELOCATED_TREE/$RELOCATED_ROOT/com/google/common/collect" ]; then
        echo "jarjar output missing relocated guava collect classes" >&2
        exit 1
    fi
    if [ ! -f "$RELOCATED_TREE/$RELOCATED_ROOT/com/google/common/util/concurrent/internal/InternalFutureFailureAccess.class" ]; then
        echo "jarjar output missing relocated failureaccess classes" >&2
        exit 1
    fi
}

patch_bundle() {
    rm -rf "$RELOCATED_ROOT"
    mkdir -p "$(dirname "$RELOCATED_ROOT")"
    cp -a "$RELOCATED_TREE/$RELOCATED_ROOT" "$(dirname "$RELOCATED_ROOT")/"

    rm -rf META-INF/maven/com.google.guava
    mkdir -p META-INF/maven/com.google.guava/guava META-INF/maven/com.google.guava/failureaccess
    write_pom_properties "$PWD" com.google.guava guava "${GUAVA_VERSION}"
    write_pom_properties "$PWD" com.google.guava failureaccess "${FAILUREACCESS_VERSION}"
    local pomdir
    pomdir="$(mktemp -d)"
    (cd "$pomdir" && jar xf "$GUAVA_JAR" META-INF/maven/com.google.guava/guava/pom.xml)
    cp "$pomdir/META-INF/maven/com.google.guava/guava/pom.xml" META-INF/maven/com.google.guava/guava/pom.xml
    rm -rf "$pomdir"

    local fresh
    fresh="$(find "$RELOCATED_ROOT" -name '*.class' -print -quit)"
    if [ -z "$fresh" ]; then
        echo "no relocated classes written into the bundle" >&2
        exit 1
    fi

    # Every reference to Guava must point at the relocated package.
    local unrelocated
    unrelocated="$(grep -rlaP '(?<![A-Za-z/])com/google/common/' "$RELOCATED_ROOT" || true)"
    if [ -n "$unrelocated" ]; then
        echo "unrelocated guava references remain:" >&2
        echo "$unrelocated" >&2
        exit 1
    fi

    javap -classpath . org.apache.iceberg.relocated.com.google.common.collect.ImmutableList >/dev/null
    javap -classpath . org.apache.iceberg.relocated.com.google.common.util.concurrent.internal.InternalFutureFailureAccess >/dev/null

    if grep -q '33\.4\.8' META-INF/maven/com.google.guava/guava/pom.properties; then
        echo "stale guava 33.4.8 metadata remains" >&2
        exit 1
    fi
}

relocate_guava
echo "repacking iceberg-bundled-guava with guava ${GUAVA_VERSION} in ${BUNDLE_JAR}"
repack_jar "$BUNDLE_JAR" patch_bundle
rm -rf "$RELOCATED_WORK"

echo "iceberg-bundled-guava remediation complete"
