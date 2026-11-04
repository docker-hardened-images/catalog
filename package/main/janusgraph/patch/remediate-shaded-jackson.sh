#!/bin/bash
# Replace vulnerable jackson-core copies shaded into fat jars: HBase's client
# and mapreduce jars, TinkerPop's gremlin-shaded, and Bigtable's HBase client.
# Maven dependencyManagement cannot reach these classes.
set -euo pipefail

JARS_DIR="${1:?usage: remediate-shaded-jackson.sh <jars-dir> <patch-deps-dir>}"
PATCH_DIR="${2:?usage: remediate-shaded-jackson.sh <jars-dir> <patch-deps-dir>}"

JARJAR_JAR="${PATCH_DIR}/jarjar-assembly-1.14.1.jar"

# <jar name prefix> <package jackson is relocated under>
SHADED_JARS=(
    "hbase-shaded-client- org.apache.hadoop.hbase.shaded.com.fasterxml.jackson"
    "hbase-shaded-mapreduce- org.apache.hadoop.hbase.shaded.com.fasterxml.jackson"
    "gremlin-shaded- org.apache.tinkerpop.shaded.jackson"
    "bigtable-hbase-2.x-shaded- com.google.bigtable.repackaged.com.faster.xml.jackson"
)

for dependency in \
    "${PATCH_DIR}/jackson-core-2.18.11.jar" \
    "${PATCH_DIR}/jackson-core-2.21.7.jar" \
    "$JARJAR_JAR"
do
    if [ ! -f "$dependency" ]; then
        echo "missing patch dependency: $dependency" >&2
        exit 1
    fi
done

relocated="$(mktemp -d)"
trap 'rm -rf "$relocated"' EXIT

relocate_jackson() {
    local version="$1"
    local package="$2"
    local prefix="${package//.//}"
    local destination="$relocated/$package/$version"

    if [ -d "$destination/$prefix/core" ]; then
        return
    fi

    mkdir -p "$destination"
    echo "rule com.fasterxml.jackson.** ${package}.@1" >"$destination.rules"
    java -jar "$JARJAR_JAR" process "$destination.rules" \
        "$PATCH_DIR/jackson-core-${version}.jar" \
        "$destination/jackson-core.jar"
    (cd "$destination" && jar xf jackson-core.jar && rm jackson-core.jar)

    if [ ! -f "$destination/$prefix/core/JsonFactory.class" ]; then
        echo "relocated jackson-core $version output is missing JsonFactory.class" >&2
        exit 1
    fi
}

# Sets REPACKED=1 when the jar was rewritten. Called outside any condition so
# that set -e still aborts on a failed step.
repack_jar() {
    local jarpath="$1"
    local package="$2"
    local prefix="${package//.//}"
    local current_version
    local destination
    local fixed_version
    local metadata
    local version
    local work

    REPACKED=0
    current_version="$(
        unzip -p "$jarpath" META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties 2>/dev/null |
            sed -n 's/^version=//p'
    )" || true
    if [ -z "$current_version" ]; then
        if unzip -Z1 "$jarpath" | grep -qx "$prefix/core/JsonFactory.class"; then
            echo "$jarpath shades jackson-core without recording its version" >&2
            exit 1
        fi
        echo "$jarpath does not shade jackson-core; leaving it unchanged"
        return
    fi
    case "$current_version" in
        2.15.2)
            echo "jackson-core $current_version in $jarpath is not affected; leaving it unchanged"
            return
            ;;
        2.17.0 | 2.18.3 | 2.18.9)
            fixed_version=2.18.11
            ;;
        2.21.1)
            fixed_version=2.21.7
            ;;
        2.18.11 | 2.21.7 | 2.22.3)
            echo "jackson-core $current_version in $jarpath is already remediated"
            return
            ;;
        *)
            echo "unsupported shaded jackson-core version $current_version in $jarpath" >&2
            exit 1
            ;;
    esac

    relocate_jackson "$fixed_version" "$package"

    work="$(mktemp -d)"

    (cd "$work" && unzip -q "$jarpath")
    if [ ! -f "$work/$prefix/core/JsonFactory.class" ]; then
        echo "$jarpath does not contain jackson-core under $prefix" >&2
        exit 1
    fi

    rm -rf "$work/$prefix/core"
    cp -a "$relocated/$package/$fixed_version/$prefix/core" "$work/$prefix/"

    for version_dir in "$work"/META-INF/versions/*; do
        [ -d "$version_dir" ] || continue
        rm -rf \
            "$version_dir/com/fasterxml/jackson/core" \
            "$version_dir/$prefix/core"
    done
    for version_dir in "$relocated/$package/$fixed_version"/META-INF/versions/*; do
        [ -d "$version_dir/$prefix/core" ] || continue
        version="$(basename "$version_dir")"
        destination="$work/META-INF/versions/$version/$prefix"
        mkdir -p "$destination"
        cp -a "$version_dir/$prefix/core" "$destination/"
    done

    metadata="$work/META-INF/maven/com.fasterxml.jackson.core/jackson-core"
    mkdir -p "$metadata"
    cat >"$metadata/pom.properties" <<EOF
artifactId=jackson-core
groupId=com.fasterxml.jackson.core
version=${fixed_version}
EOF

    # zip, not jar: JDK 17's jar refuses to rewrite a jar whose
    # module-info.class targets a newer release (hbase-shaded-client 2.6.6).
    # The manifest goes first so JarInputStream still finds it.
    rm -f "$work.jar"
    (
        cd "$work"
        if [ -f META-INF/MANIFEST.MF ]; then
            zip -qX "$work.jar" META-INF/MANIFEST.MF
        fi
        zip -qrX "$work.jar" . -x META-INF/MANIFEST.MF
    )

    javap -verbose -classpath "$work.jar" "${package}.core.JsonFactory" |
        grep -q "this_class:.*$prefix/core/JsonFactory"
    unzip -p "$work.jar" META-INF/maven/com.fasterxml.jackson.core/jackson-core/pom.properties |
        grep -q "^version=${fixed_version}$"
    if unzip -Z1 "$work.jar" | grep -Eq 'com/fasterxml/jackson/core/io/doubleparser|v2_(17_0|18_3|18_9|21_1)'; then
        echo "stale jackson-core classes remain in $jarpath" >&2
        exit 1
    fi

    mv "$work.jar" "$jarpath"
    rm -rf "$work"
    REPACKED=1
}

remediated=0
for entry in "${SHADED_JARS[@]}"; do
    read -r artifact package <<<"$entry"
    jarpath="$(find "$JARS_DIR" -maxdepth 1 -type f -name "${artifact}*.jar" -print -quit)"
    if [ -z "$jarpath" ]; then
        echo "${artifact%-} jar not found under $JARS_DIR" >&2
        exit 1
    fi
    repack_jar "$jarpath" "$package"
    remediated=$((remediated + REPACKED))
done

echo "shaded jackson-core inspection complete; remediated $remediated jar(s)"
