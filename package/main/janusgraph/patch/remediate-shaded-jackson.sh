#!/bin/bash
# Replace vulnerable jackson-core, jackson-databind and jackson-annotations
# copies shaded into fat jars: HBase's client and mapreduce jars, TinkerPop's
# gremlin-shaded, and Bigtable's HBase client. Maven dependencyManagement
# cannot reach these classes.
#
# Every module a jar shades is moved to the same patch line (2.18.11 or
# 2.21.7) so core, databind and annotations stay mutually compatible.
# jackson-annotations is only replaced when databind moves to a newer minor
# than the shaded annotations (databind 2.18 needs 2.18 annotations).
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
    "${PATCH_DIR}/jackson-databind-2.18.11.jar" \
    "${PATCH_DIR}/jackson-databind-2.21.7.jar" \
    "${PATCH_DIR}/jackson-annotations-2.18.11.jar" \
    "$JARJAR_JAR"
do
    if [ ! -f "$dependency" ]; then
        echo "missing patch dependency: $dependency" >&2
        exit 1
    fi
done

relocated="$(mktemp -d)"
trap 'rm -rf "$relocated"' EXIT

# <artifact> <package directory under the relocation prefix> <marker class>
module_dir() {
    case "$1" in
        jackson-core) echo core ;;
        jackson-databind) echo databind ;;
        jackson-annotations) echo annotation ;;
    esac
}

module_marker() {
    case "$1" in
        jackson-core) echo core/JsonFactory.class ;;
        jackson-databind) echo databind/ObjectMapper.class ;;
        jackson-annotations) echo annotation/JsonProperty.class ;;
    esac
}

shaded_version() {
    local jarpath="$1"
    local artifact="$2"

    unzip -p "$jarpath" "META-INF/maven/com.fasterxml.jackson.core/${artifact}/pom.properties" 2>/dev/null |
        sed -n 's/^version=//p' || true
}

# Prints the patch line a jar's jackson modules move to, or nothing when every
# shaded module is already remediated.
target_line() {
    local version="$1"

    case "$version" in
        2.15.2 | 2.17.0 | 2.18.3 | 2.18.9)
            echo 2.18.11
            ;;
        2.21.1)
            echo 2.21.7
            ;;
        2.18.11 | 2.21.7 | 2.22.3 | "")
            ;;
        *)
            echo "unsupported shaded jackson version $version" >&2
            exit 1
            ;;
    esac
}

relocate_module() {
    local artifact="$1"
    local version="$2"
    local package="$3"
    local prefix="${package//.//}"
    local destination="$relocated/$package/$artifact/$version"

    if [ -d "$destination/$prefix" ]; then
        return
    fi

    mkdir -p "$destination"
    echo "rule com.fasterxml.jackson.** ${package}.@1" >"$destination.rules"
    java -jar "$JARJAR_JAR" process "$destination.rules" \
        "$PATCH_DIR/${artifact}-${version}.jar" \
        "$destination/module.jar"
    (cd "$destination" && jar xf module.jar && rm module.jar)

    if [ ! -f "$destination/$prefix/$(module_marker "$artifact")" ]; then
        echo "relocated $artifact $version output is missing $(module_marker "$artifact")" >&2
        exit 1
    fi
}

replace_module() {
    local work="$1"
    local artifact="$2"
    local version="$3"
    local package="$4"
    local prefix="${package//.//}"
    local dir
    local release
    local destination
    local source="$relocated/$package/$artifact/$version"

    dir="$(module_dir "$artifact")"
    relocate_module "$artifact" "$version" "$package"

    if [ ! -f "$work/$prefix/$(module_marker "$artifact")" ]; then
        echo "$artifact is not shaded under $prefix" >&2
        exit 1
    fi

    rm -rf "${work:?}/${prefix:?}/${dir:?}"
    cp -a "$source/$prefix/$dir" "$work/$prefix/"

    for version_dir in "$work"/META-INF/versions/*; do
        [ -d "$version_dir" ] || continue
        rm -rf \
            "$version_dir/com/fasterxml/jackson/$dir" \
            "${version_dir:?}/${prefix:?}/${dir:?}"
    done
    for version_dir in "$source"/META-INF/versions/*; do
        [ -d "$version_dir/$prefix/$dir" ] || continue
        release="$(basename "$version_dir")"
        destination="$work/META-INF/versions/$release/$prefix"
        mkdir -p "$destination"
        cp -a "$version_dir/$prefix/$dir" "$destination/"
    done

    mkdir -p "$work/META-INF/maven/com.fasterxml.jackson.core/$artifact"
    cat >"$work/META-INF/maven/com.fasterxml.jackson.core/$artifact/pom.properties" <<EOF
artifactId=${artifact}
groupId=com.fasterxml.jackson.core
version=${version}
EOF
}

# Sets REPACKED=1 when the jar was rewritten. Called outside any condition so
# that set -e still aborts on a failed step.
repack_jar() {
    local jarpath="$1"
    local package="$2"
    local prefix="${package//.//}"
    local artifact
    local current
    local entry
    local line
    local annotations_minor
    local line_minor
    local replace=()
    local work

    REPACKED=0
    for artifact in jackson-core jackson-databind jackson-annotations; do
        current="$(shaded_version "$jarpath" "$artifact")"
        if [ -z "$current" ] &&
            unzip -Z1 "$jarpath" | grep -qx "$prefix/$(module_marker "$artifact")"; then
            echo "$jarpath shades $artifact without recording its version" >&2
            exit 1
        fi
        if [ "$artifact" = jackson-annotations ]; then
            continue
        fi
        line="$(target_line "$current")"
        if [ -n "$line" ]; then
            replace+=("$artifact:$line")
        fi
    done

    if [ "${#replace[@]}" -eq 0 ]; then
        echo "$jarpath shaded jackson is already remediated or absent; leaving it unchanged"
        return
    fi

    # Annotations follow databind when databind moves to a newer minor.
    current="$(shaded_version "$jarpath" jackson-annotations)"
    for entry in "${replace[@]}"; do
        [ "${entry%%:*}" = jackson-databind ] || continue
        line="${entry#*:}"
        line_minor="$(echo "$line" | cut -d. -f1-2)"
        annotations_minor="$(echo "$current" | cut -d. -f1-2)"
        if [ -n "$current" ] && [ "$annotations_minor" != "$line_minor" ]; then
            replace+=("jackson-annotations:$line")
        fi
    done

    work="$(mktemp -d)"
    (cd "$work" && unzip -q "$jarpath")

    for entry in "${replace[@]}"; do
        echo "replacing ${entry%%:*} $(shaded_version "$jarpath" "${entry%%:*}") with ${entry#*:} in $jarpath"
        replace_module "$work" "${entry%%:*}" "${entry#*:}" "$package"
    done

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

    for entry in "${replace[@]}"; do
        artifact="${entry%%:*}"
        javap -verbose -classpath "$work.jar" \
            "${package}.$(module_marker "$artifact" | sed 's|/|.|; s|\.class$||')" |
            grep -q "this_class:.*$prefix/$(module_marker "$artifact" | sed 's|\.class$||')"
        unzip -p "$work.jar" "META-INF/maven/com.fasterxml.jackson.core/$artifact/pom.properties" |
            grep -q "^version=${entry#*:}$"
    done
    if unzip -Z1 "$work.jar" | grep -Eq 'com/fasterxml/jackson/core/io/doubleparser|v2_(15_2|17_0|18_3|18_9|21_1)'; then
        echo "stale jackson classes remain in $jarpath" >&2
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

echo "shaded jackson inspection complete; remediated $remediated jar(s)"
