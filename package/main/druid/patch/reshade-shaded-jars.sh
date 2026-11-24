#!/bin/bash
# Replace vulnerable library copies that Druid ships only inside shaded
# third-party jars. Maven pins cannot reach them: the classes are relocated
# into the shading jar's own package prefix, and no fixed release of the
# shading jar exists. reshade/pom.xml relocates the fixed releases into the
# same prefixes (rewriting the bytecode, not only the paths); this script swaps
# those trees in, carries the fixed releases' META-INF/maven metadata so the
# SBOM reports them, and fails unless check-jar-refs.py shows that no class or
# member reference in the jar stopped resolving.
#
# usage: reshade-shaded-jars.sh <druid-home> <reshade-target-dir>
set -euo pipefail

DRUID_HOME="$(readlink -f "${1:?usage: reshade-shaded-jars.sh <druid-home> <reshade-target-dir>}")"
RESHADE="$(readlink -f "${2:?usage: reshade-shaded-jars.sh <druid-home> <reshade-target-dir>}")"
HERE="$(dirname "$(readlink -f "$0")")"

for f in reshade-1-hadoop reshade-1-hadoop336 reshade-1-iceberg reshade-1-ambari; do
    test -f "${RESHADE}/${f}.jar"
done

CACHE="$(mktemp -d)"
trap 'rm -rf "$CACHE"' EXIT

# patch_one <jar> <new-jar> <checker-prefixes> <roots> <drops> <callers>
# Each list argument is space separated. Roots and drops are paths inside the
# jar; callers are jars whose classes call into this one and must still link.
# Every META-INF/maven/<groupId>/<artifactId> directory in the new jar replaces
# the same directory in the target, which must already have one.
patch_one() {
    local jar="$1" new="$2" prefixes="$3" roots="$4" drops="$5" callers="$6"
    local work fresh out p r c d
    work="$(mktemp -d)"
    fresh="$(mktemp -d)"
    out="$(mktemp -u).jar"
    (cd "$work" && jar xf "$jar")
    (cd "$fresh" && jar xf "$new")

    for r in $roots; do
        test -d "$work/$r" || { echo "$jar: no $r to replace" >&2; return 1; }
        test -d "$fresh/$r" || { echo "$new: no $r" >&2; return 1; }
        rm -r "$work/$r"
        cp -a "$fresh/$r" "$work/$r"
    done
    for c in "$fresh"/META-INF/maven/*/*/; do
        c="${c#"$fresh/META-INF/maven/"}"
        c="${c%/}"
        [ "$c" = com.docker.dhi.druid/reshade ] && continue
        test -d "$work/META-INF/maven/$c" || { echo "$jar: no metadata for $c" >&2; return 1; }
        rm -r "$work/META-INF/maven/$c"
        cp -a "$fresh/META-INF/maven/$c" "$work/META-INF/maven/$c"
    done
    for d in $drops; do
        test -e "$work/$d" || { echo "$jar: no $d to drop" >&2; return 1; }
        rm -r "$work/$d"
    done

    mv "$work/META-INF/MANIFEST.MF" "$fresh/MANIFEST.MF.orig"
    jar --create --file "$out" --manifest "$fresh/MANIFEST.MF.orig" -C "$work" .

    local args=()
    for p in $prefixes; do
        args+=(--prefix "$p")
    done
    for c in $callers; do
        args+=(--with "$c")
    done
    python3 -I "$HERE/check-jar-refs.py" "${args[@]}" "$jar" "$out"

    install -m 0644 "$out" "$jar"
    rm -rf "$work" "$fresh" "$out"
}

# patch_all <file-name-glob> <spec-function>: every matching jar is passed to
# the spec function with its path and version; identical copies are patched
# once and the result reused.
patch_all() {
    local glob="$1" spec="$2" jar sum found=0
    while IFS= read -r jar; do
        found=1
        sum="$(sha256sum "$jar" | cut -d' ' -f1)"
        if [ -f "$CACHE/$sum" ]; then
            install -m 0644 "$CACHE/$sum" "$jar"
        else
            "$spec" "$jar"
            cp "$jar" "$CACHE/$sum"
        fi
        echo "re-shaded $jar"
    done < <(find "$DRUID_HOME" -type f -name "$glob" | sort)
    if [ "$found" -eq 0 ]; then
        echo "no $glob under $DRUID_HOME" >&2
        return 1
    fi
}

maven_version() {
    unzip -p "$1" "META-INF/maven/$2/pom.properties" | sed -n 's/^version=//p' | tr -d '\r'
}

H=org/apache/hadoop/shaded
T=org/apache/hadoop/thirdparty
HADOOP_ROOTS="$H/com/fasterxml/jackson/annotation $H/com/fasterxml/jackson/core
    $H/com/fasterxml/jackson/databind $H/com/google/common $H/com/google/thirdparty
    $T/com/google/common $T/com/google/thirdparty $H/org/apache/commons/configuration2
    $H/org/apache/commons/io $H/org/apache/commons/lang3 $H/org/apache/commons/text
    $H/org/apache/kerby"

# hadoop-client-runtime, checked against the hadoop-client-api of the same
# release (Hadoop's own classes, the callers of everything shaded here).
#   3.5.0: jackson 2.18.6, guava 33.4.8 (the org.apache.hadoop.shaded copy and
#          the hadoop-shaded-guava 1.5.0 copy), commons-configuration2 2.10.1
#          with the commons-io, lang3 and text releases it is built against,
#          and kerby 2.0.3. Its jackson-core multi-release entries were never
#          relocated and the manifest is not Multi-Release, so they are dead
#          2.18.6 classes; drop them.
#   3.3.6: the same set at older releases, plus jetty 9.4.51, beanutils 1.9.4,
#          nimbus-jose-jwt 9.8.1 (its shaded tree holds the json-smart 1.3.2
#          classes, so json-smart's metadata goes with it), commons-compress
#          1.21 and avro 1.7.7. dnsjava 2.1.7 stays: SecurityUtil in 3.3.6
#          calls ResolverConfig.searchPath() returning Name[], which dnsjava 3
#          (the only fixed line) returns as a List. protobuf stays: both
#          copies (2.5 under org.apache.hadoop.shaded, 3.7.1 under
#          org.apache.hadoop.thirdparty) back Hadoop RPC.
spec_hadoop_client_runtime() {
    local jar="$1" version api
    version="$(basename "$jar" .jar)"
    version="${version#hadoop-client-runtime-}"
    api="$(find "$DRUID_HOME" -type f -name "hadoop-client-api-${version}.jar" -print -quit)"
    test -n "$api" || { echo "no hadoop-client-api-${version}.jar to check $jar against" >&2; return 1; }
    case "$version" in
        3.5.0)
            patch_one "$jar" "${RESHADE}/reshade-1-hadoop.jar" "$H/ $T/" "$HADOOP_ROOTS" \
                "META-INF/versions/11/com/fasterxml/jackson/core
                 META-INF/versions/17/com/fasterxml/jackson/core
                 META-INF/versions/21/com/fasterxml/jackson/core" \
                "$api"
            ;;
        3.3.6)
            patch_one "$jar" "${RESHADE}/reshade-1-hadoop336.jar" "$H/ $T/" \
                "$HADOOP_ROOTS $H/org/eclipse/jetty $H/org/apache/commons/beanutils $H/com/nimbusds
                 $H/org/apache/commons/compress $H/org/apache/avro" \
                "META-INF/maven/net.minidev" \
                "$api"
            ;;
        *)
            echo "$jar: no re-shade spec for hadoop-client-runtime $version" >&2
            return 1
            ;;
    esac
}

# iceberg-bundled-guava: relocated guava 33.x, checked against the iceberg jars
# beside it.
spec_iceberg_bundled_guava() {
    local jar="$1" v callers
    v="$(maven_version "$jar" com.google.guava/guava)"
    case "$v" in
        33.*-jre) ;;
        *)
            echo "$jar: bundles guava $v, expected a 33.x-jre release" >&2
            return 1
            ;;
    esac
    callers="$(find "$(dirname "$jar")" -maxdepth 1 -name 'iceberg-*.jar' ! -name 'iceberg-bundled-guava-*' | sort | tr '\n' ' ')"
    test -n "$callers" || { echo "no iceberg jars beside $jar" >&2; return 1; }
    patch_one "$jar" "${RESHADE}/reshade-1-iceberg.jar" "org/apache/iceberg/relocated/" \
        "org/apache/iceberg/relocated/com/google/common" "" "$callers"
}

# ambari-metrics-common 2.7.0.0.0 (Ambari's last release): httpclient 4.5.2 and
# httpcore 4.4.4. Its callers are the Ambari classes in the same jar.
spec_ambari_metrics_common() {
    local jar="$1"
    case "$(basename "$jar")" in
        ambari-metrics-common-2.7.0.0.0.jar) ;;
        *)
            echo "$jar: no re-shade spec for this ambari-metrics-common release" >&2
            return 1
            ;;
    esac
    patch_one "$jar" "${RESHADE}/reshade-1-ambari.jar" "org/apache/ambari/metrics/" \
        "org/apache/ambari/metrics/sink/relocated/apache/http" "" ""
}

patch_all 'hadoop-client-runtime-*.jar' spec_hadoop_client_runtime
patch_all 'iceberg-bundled-guava-*.jar' spec_iceberg_bundled_guava
patch_all 'ambari-metrics-common-*.jar' spec_ambari_metrics_common
