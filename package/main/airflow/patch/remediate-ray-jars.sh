#!/bin/bash
# Replace Ray's shaded Jackson and Guava copies with fixed patch releases.
set -euo pipefail

RAY_JAR="${1:?usage: remediate-ray-jars.sh <ray-dist.jar> <patch-dir> <jackson-version> <guava-version>}"
PATCH_DIR="${2:?usage: remediate-ray-jars.sh <ray-dist.jar> <patch-dir> <jackson-version> <guava-version>}"
JACKSON_VERSION="${3:?usage: remediate-ray-jars.sh <ray-dist.jar> <patch-dir> <jackson-version> <guava-version>}"
GUAVA_VERSION="${4:?usage: remediate-ray-jars.sh <ray-dist.jar> <patch-dir> <jackson-version> <guava-version>}"

JACKSON_CORE="${PATCH_DIR}/jackson-core-${JACKSON_VERSION}.jar"
JACKSON_DATABIND="${PATCH_DIR}/jackson-databind-${JACKSON_VERSION}.jar"
JACKSON_ANNOTATIONS="${PATCH_DIR}/jackson-annotations-${JACKSON_VERSION}.jar"
GUAVA="${PATCH_DIR}/guava-${GUAVA_VERSION}.jar"
JARJAR="${PATCH_DIR}/jarjar-assembly-1.14.1.jar"

for dependency in \
    "$JACKSON_CORE" "$JACKSON_DATABIND" "$JACKSON_ANNOTATIONS" \
    "$GUAVA" "$JARJAR"
do
    if [ ! -f "$dependency" ]; then
        echo "missing Ray remediation dependency: $dependency" >&2
        exit 1
    fi
done

if [ ! -f "$RAY_JAR" ]; then
    echo "Ray JAR not found: $RAY_JAR" >&2
    exit 1
fi

work="$(mktemp -d)"
outputs="$(mktemp -d)"
manifest="$(mktemp)"
rules="$(mktemp)"
trap 'rm -rf "$work" "$outputs" "$manifest" "$rules"' EXIT

(cd "$work" && jar xf "$RAY_JAR")

read_version() {
    local group="$1"
    local artifact="$2"
    sed -n 's/^version=//p' \
        "$work/META-INF/maven/$group/$artifact/pom.properties" | head -1
}

assert_older() {
    local group="$1"
    local artifact="$2"
    local target="$3"
    local bundled
    local older
    bundled="$(read_version "$group" "$artifact")"
    if [ -z "$bundled" ]; then
        echo "$group/$artifact metadata is missing from Ray JAR" >&2
        exit 1
    fi
    older="$(printf '%s\n%s\n' "$bundled" "$target" | sort -V | head -1)"
    if [ "$older" != "$bundled" ] || [ "$bundled" = "$target" ]; then
        echo "$group/$artifact $bundled is already >= $target" >&2
        exit 1
    fi
}

assert_older com.fasterxml.jackson.core jackson-core "$JACKSON_VERSION"
assert_older com.fasterxml.jackson.core jackson-databind "$JACKSON_VERSION"
assert_older com.fasterxml.jackson.core jackson-annotations "$JACKSON_VERSION"
assert_older com.google.guava guava "$GUAVA_VERSION"

relocate() {
    local source_jar="$1"
    local output_jar="$2"
    local rule="$3"
    printf '%s\n' "$rule" >"$rules"
    java -jar "$JARJAR" process "$rules" "$source_jar" "$output_jar"
}

relocate "$JACKSON_CORE" "$outputs/jackson-core.jar" \
    'rule com.fasterxml.jackson.** io.ray.shaded.com.fasterxml.jackson.@1'
relocate "$JACKSON_DATABIND" "$outputs/jackson-databind.jar" \
    'rule com.fasterxml.jackson.** io.ray.shaded.com.fasterxml.jackson.@1'
relocate "$JACKSON_ANNOTATIONS" "$outputs/jackson-annotations.jar" \
    'rule com.fasterxml.jackson.** io.ray.shaded.com.fasterxml.jackson.@1'
relocate "$GUAVA" "$outputs/guava.jar" \
    'rule com.google.** io.ray.shaded.com.google.@1'

# failureaccess and the listenablefuture compatibility artifact share Guava's
# package but are separate dependencies. Preserve their classes while replacing
# the classes owned by the Guava JAR itself.
mkdir -p "$outputs/preserved-guava-internal"
if [ -d "$work/io/ray/shaded/com/google/common/util/concurrent/internal" ]; then
    cp -a "$work/io/ray/shaded/com/google/common/util/concurrent/internal" \
        "$outputs/preserved-guava-internal/"
fi

rm -rf \
    "$work/io/ray/shaded/com/fasterxml/jackson" \
    "$work/io/ray/shaded/com/google/common" \
    "$work/io/ray/shaded/com/google/thirdparty" \
    "$work/META-INF/maven/com.fasterxml.jackson.core/jackson-core" \
    "$work/META-INF/maven/com.fasterxml.jackson.core/jackson-databind" \
    "$work/META-INF/maven/com.fasterxml.jackson.core/jackson-annotations" \
    "$work/META-INF/maven/com.google.guava/guava"

if [ -d "$work/META-INF/versions" ]; then
    while IFS= read -r path; do
        rm -rf "$path"
    done < <(find "$work/META-INF/versions" -type d \
        \( -path '*/com/fasterxml/jackson' -o -path '*/io/ray/shaded/com/fasterxml/jackson' \) \
        -prune -print)
fi

merge_relocated() {
    local relocated_jar="$1"
    local root_prefix="$2"
    local group="$3"
    local artifact="$4"
    local extracted
    extracted="$(mktemp -d)"
    (cd "$extracted" && jar xf "$relocated_jar")

    if [ ! -d "$extracted/$root_prefix" ]; then
        echo "relocated output lacks $root_prefix: $relocated_jar" >&2
        exit 1
    fi
    mkdir -p "$work/$(dirname "$root_prefix")"
    cp -a "$extracted/$root_prefix" "$work/$(dirname "$root_prefix")/"

    for version_dir in "$extracted"/META-INF/versions/*; do
        [ -d "$version_dir/$root_prefix" ] || continue
        version="$(basename "$version_dir")"
        mkdir -p "$work/META-INF/versions/$version/$(dirname "$root_prefix")"
        cp -a "$version_dir/$root_prefix" \
            "$work/META-INF/versions/$version/$(dirname "$root_prefix")/"
    done

    if [ -d "$extracted/META-INF/services" ]; then
        mkdir -p "$work/META-INF/services"
        cp -a "$extracted/META-INF/services/." "$work/META-INF/services/"
    fi

    mkdir -p "$work/META-INF/maven/$group"
    cp -a "$extracted/META-INF/maven/$group/$artifact" \
        "$work/META-INF/maven/$group/"
    rm -rf "$extracted"
}

merge_relocated "$outputs/jackson-core.jar" \
    io/ray/shaded/com/fasterxml/jackson/core \
    com.fasterxml.jackson.core jackson-core
merge_relocated "$outputs/jackson-databind.jar" \
    io/ray/shaded/com/fasterxml/jackson/databind \
    com.fasterxml.jackson.core jackson-databind
merge_relocated "$outputs/jackson-annotations.jar" \
    io/ray/shaded/com/fasterxml/jackson/annotation \
    com.fasterxml.jackson.core jackson-annotations
merge_relocated "$outputs/guava.jar" \
    io/ray/shaded/com/google \
    com.google.guava guava

if [ -d "$outputs/preserved-guava-internal/internal" ]; then
    mkdir -p "$work/io/ray/shaded/com/google/common/util/concurrent"
    cp -a "$outputs/preserved-guava-internal/internal" \
        "$work/io/ray/shaded/com/google/common/util/concurrent/"
fi

for component in \
    "com.fasterxml.jackson.core jackson-core $JACKSON_VERSION" \
    "com.fasterxml.jackson.core jackson-databind $JACKSON_VERSION" \
    "com.fasterxml.jackson.core jackson-annotations $JACKSON_VERSION" \
    "com.google.guava guava $GUAVA_VERSION"
do
    read -r group artifact expected <<<"$component"
    actual="$(read_version "$group" "$artifact")"
    if [ "$actual" != "$expected" ]; then
        echo "$group/$artifact metadata is $actual, expected $expected" >&2
        exit 1
    fi
done

javap -verbose "$work/io/ray/shaded/com/fasterxml/jackson/core/JsonFactory.class" \
    | grep -q 'this_class:.*io/ray/shaded/com/fasterxml/jackson/core/JsonFactory'
javap -verbose "$work/io/ray/shaded/com/fasterxml/jackson/databind/ObjectMapper.class" \
    | grep -q 'this_class:.*io/ray/shaded/com/fasterxml/jackson/databind/ObjectMapper'
javap -verbose "$work/io/ray/shaded/com/google/common/base/Preconditions.class" \
    | grep -q 'this_class:.*io/ray/shaded/com/google/common/base/Preconditions'

stale="$(
    find "$work" -type f -path '*v2_18_8*' -print
    if [ -d "$work/META-INF/versions" ]; then
        find "$work/META-INF/versions" -regextype posix-extended -type f \
            -regex '.*/META-INF/versions/[^/]+/com/fasterxml/jackson/.*\.class' -print
    fi
)"
if [ -n "$stale" ]; then
    echo "stale or unshaded Jackson classes remain in Ray JAR:" >&2
    printf '%s\n' "$stale" >&2
    exit 1
fi

cat >"$work/RayDependencySmoke.java" <<'EOF'
import io.ray.shaded.com.fasterxml.jackson.databind.ObjectMapper;
import io.ray.shaded.com.google.common.base.Preconditions;

public class RayDependencySmoke {
    public static void main(String[] args) throws Exception {
        Preconditions.checkArgument(
            "value".equals(new ObjectMapper().readTree("{\"key\":\"value\"}").get("key").asText())
        );
    }
}
EOF
(cd "$work" && javac -cp . RayDependencySmoke.java && java -cp . RayDependencySmoke)
rm -f "$work/RayDependencySmoke.java" "$work/RayDependencySmoke.class"

cp "$work/META-INF/MANIFEST.MF" "$manifest"
rm -f "$work/META-INF/MANIFEST.MF"
replacement="${RAY_JAR}.replacement"
rm -f "$replacement"
(cd "$work" && jar cfm "$replacement" "$manifest" .)
mv "$replacement" "$RAY_JAR"

echo "Ray shaded Jackson and Guava remediation complete"
