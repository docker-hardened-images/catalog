#!/bin/bash
# Repack shaded Guava (iceberg-bundled-guava) and Jackson (parquet-hadoop-bundle /
# parquet-jackson) under the Elasticsearch distribution tree. Gradle
# resolutionStrategy fixes loose coordinates; scanners still flag bytecode-shaded
# copies until jarjar rewrites the relocated prefixes in place.
set -euo pipefail

JARS_ROOT="${1:?usage: remediate-shaded-deps.sh <distribution-root> <patch-deps-dir> <jackson-version>}"
PATCH_DIR="${2:?usage: remediate-shaded-deps.sh <distribution-root> <patch-deps-dir> <jackson-version>}"
JACKSON_VERSION="${3:?usage: remediate-shaded-deps.sh <distribution-root> <patch-deps-dir> <jackson-version>}"

GUAVA_JAR="${PATCH_DIR}/guava-33.7.2-jre.jar"
FAILUREACCESS_JAR="${PATCH_DIR}/failureaccess-1.0.3.jar"
JACKSON_CORE="${PATCH_DIR}/jackson-core-${JACKSON_VERSION}.jar"
JACKSON_DATABIND="${PATCH_DIR}/jackson-databind-${JACKSON_VERSION}.jar"
JACKSON_ANNOTATIONS="${PATCH_DIR}/jackson-annotations-2.22.jar"
JARJAR_GUAVA_CP="${PATCH_DIR}/jarjar-1.7.2.jar:${PATCH_DIR}/asm-7.0.jar:${PATCH_DIR}/asm-commons-7.0.jar"
JARJAR_JACKSON="${PATCH_DIR}/jarjar-assembly-1.14.1.jar"
FDP_VERSION="v${JACKSON_VERSION//./_}"

for jar in "$GUAVA_JAR" "$FAILUREACCESS_JAR" "$JACKSON_CORE" "$JACKSON_DATABIND" \
    "$JACKSON_ANNOTATIONS" "$JARJAR_JACKSON" \
    "${PATCH_DIR}/jarjar-1.7.2.jar" "${PATCH_DIR}/asm-7.0.jar" "${PATCH_DIR}/asm-commons-7.0.jar"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

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

install_shaded_prefix() {
    local out="$1"
    local shaded_prefix="$2"
    local verpath
    local ver

    rm -rf "$shaded_prefix"
    if [ -d META-INF/versions ]; then
        find META-INF/versions -type d -path "*/${shaded_prefix}" -prune -exec rm -rf {} + 2>/dev/null || true
    fi
    if [ ! -d "$out/$shaded_prefix" ]; then
        echo "jarjar output missing $shaded_prefix" >&2
        exit 1
    fi
    mkdir -p "$(dirname "$shaded_prefix")"
    cp -a "$out/$shaded_prefix" "$(dirname "$shaded_prefix")/"

    for verpath in "$out"/META-INF/versions/*/; do
        [ -d "$verpath" ] || continue
        ver="$(basename "$verpath")"
        if [ -d "$verpath/$shaded_prefix" ]; then
            mkdir -p "META-INF/versions/$ver/$(dirname "$shaded_prefix")"
            rm -rf "META-INF/versions/$ver/$shaded_prefix"
            cp -a "$verpath/$shaded_prefix" "META-INF/versions/$ver/$(dirname "$shaded_prefix")/"
        fi
    done
}

merge_jarjar_shaded_tree_guava() {
    local srcjar="$1"
    shift
    local rules
    local out
    local shaded_prefix
    rules="$(mktemp)"
    out="$(mktemp -d)"
    # InternetDomainName in Guava 33.7.2 references com.google.thirdparty.publicsuffix.
    # Relocate that tree beside com.google.common in Iceberg's namespace.
    cat >"$rules" <<'EOF'
rule com.google.common.** org.apache.iceberg.relocated.com.google.common.@1
rule com.google.thirdparty.** org.apache.iceberg.relocated.com.google.thirdparty.@1
EOF
    java -cp "$JARJAR_GUAVA_CP" org.pantsbuild.jarjar.Main process "$rules" "$srcjar" "$out/relocated.jar"
    rm -f "$rules"

    (cd "$out" && jar xf relocated.jar)
    if [ "$#" -eq 0 ]; then
        echo "merge_jarjar_shaded_tree_guava: no shaded prefixes" >&2
        exit 1
    fi
    for shaded_prefix in "$@"; do
        install_shaded_prefix "$out" "$shaded_prefix"
    done

    if [ -d "$out/META-INF/services" ]; then
        mkdir -p META-INF/services
        cp -a "$out/META-INF/services/." META-INF/services/
    fi
    rm -rf "$out"
}

merge_jarjar_shaded_tree_jackson() {
    local srcjar="$1"
    local shaded_prefix="$2"
    local rules
    local out
    rules="$(mktemp)"
    out="$(mktemp -d)"
    echo 'rule com.fasterxml.jackson.** shaded.parquet.com.fasterxml.jackson.@1' >"$rules"
    java -jar "$JARJAR_JACKSON" process "$rules" "$srcjar" "$out/relocated.jar"
    rm -f "$rules"

    (cd "$out" && jar xf relocated.jar)
    rm -rf "$shaded_prefix"
    if [ -d META-INF/versions ]; then
        find META-INF/versions -type d -path "*/${shaded_prefix}" -prune -exec rm -rf {} +
    fi
    if [ ! -d "$out/$shaded_prefix" ]; then
        echo "jarjar output missing $shaded_prefix from $srcjar" >&2
        exit 1
    fi
    mkdir -p "$(dirname "$shaded_prefix")"
    cp -a "$out/$shaded_prefix" "$(dirname "$shaded_prefix")/"

    if [ -d "$out/META-INF/services" ]; then
        mkdir -p META-INF/services
        cp -a "$out/META-INF/services/." META-INF/services/
    fi
    for verpath in "$out"/META-INF/versions/*/; do
        [ -d "$verpath" ] || continue
        ver="$(basename "$verpath")"
        if [ -d "$verpath/$shaded_prefix" ]; then
            mkdir -p "META-INF/versions/$ver/$(dirname "$shaded_prefix")"
            cp -a "$verpath/$shaded_prefix" "META-INF/versions/$ver/$(dirname "$shaded_prefix")/"
        fi
    done
    rm -rf "$out"
}

build_guava_reloc_input() {
    local outjar="$1"
    local work
    work="$(mktemp -d)"
    (
        cd "$work"
        jar xf "$GUAVA_JAR"
        jar xf "$FAILUREACCESS_JAR"
        jar cf "$outjar" .
    )
    rm -rf "$work"
}

verify_javap_contains() {
    local classname="$1"
    local expected_prefix="$2"
    local expected_suffix="${3:-}"
    local output
    local line

    if ! output="$(javap -verbose -classpath . "$classname")"; then
        echo "javap failed for ${classname}" >&2
        return 1
    fi
    while IFS= read -r line; do
        case "$line" in
            *"$expected_prefix"*"$expected_suffix"*)
                return 0
                ;;
        esac
    done <<<"$output"
    echo "javap output for ${classname} missing ${expected_prefix}...${expected_suffix}" >&2
    return 1
}

verify_public_suffix_lookup() {
    local classname="$1"
    local probe
    local probe_src

    probe="$(mktemp -d)"
    probe_src="${probe}/PublicSuffixProbe.java"
    cat >"$probe_src" <<EOF
public class PublicSuffixProbe {
    public static void main(String[] args) {
        String suffix = ${classname}.from("example.com").publicSuffix().toString();
        if (!"com".equals(suffix)) {
            System.err.println("unexpected public suffix for example.com: " + suffix);
            System.exit(1);
        }
    }
}
EOF
    if ! javac -cp . -d "$probe" "$probe_src"; then
        echo "failed to compile public suffix probe for ${classname}" >&2
        rm -rf "$probe"
        return 1
    fi
    if ! java -cp ".:${probe}" PublicSuffixProbe; then
        echo "public suffix lookup failed for ${classname}" >&2
        rm -rf "$probe"
        return 1
    fi
    rm -rf "$probe"
}

verify_relocated_guava_closure() {
    local prefix="$1"
    local preconditions="${prefix}.base.Preconditions"
    local abstract_future="${prefix}.util.concurrent.AbstractFuture"
    local internal_fa="${prefix}.util.concurrent.internal.InternalFutureFailureAccess"
    local domain_name
    local public_suffix
    local preconditions_path
    local abstract_future_path
    local internal_fa_path
    local public_suffix_path

    case "$prefix" in
        org.apache.iceberg.relocated.com.google.common)
            domain_name='org.apache.iceberg.relocated.com.google.common.net.InternetDomainName'
            public_suffix='org.apache.iceberg.relocated.com.google.thirdparty.publicsuffix.PublicSuffixPatterns'
            preconditions_path='org/apache/iceberg/relocated/com/google/common/base/Preconditions'
            abstract_future_path='org/apache/iceberg/relocated/com/google/common/util/concurrent/AbstractFuture'
            internal_fa_path='org/apache/iceberg/relocated/com/google/common/util/concurrent/internal/InternalFutureFailureAccess'
            public_suffix_path='org/apache/iceberg/relocated/com/google/thirdparty/publicsuffix/PublicSuffixPatterns'
            ;;
        *)
            echo "unknown relocated guava prefix: $prefix" >&2
            return 1
            ;;
    esac

    verify_javap_contains "$preconditions" "this_class:" "$preconditions_path"
    javap -classpath . "$internal_fa" >/dev/null
    verify_javap_contains "$internal_fa" "this_class:" "$internal_fa_path"
    javap -classpath . "$abstract_future" >/dev/null
    verify_javap_contains "$abstract_future" "this_class:" "$abstract_future_path"
    verify_javap_contains "$abstract_future" "$internal_fa_path"
    verify_javap_contains "$public_suffix" "this_class:" "$public_suffix_path"
    verify_javap_contains "$domain_name" "$public_suffix_path"
    verify_public_suffix_lookup "$domain_name"
}

patch_iceberg_guava_jar() {
    local input
    input="$(mktemp)"
    build_guava_reloc_input "$input"
    merge_jarjar_shaded_tree_guava "$input" \
        org/apache/iceberg/relocated/com/google/common \
        org/apache/iceberg/relocated/com/google/thirdparty
    rm -f "$input"
    write_pom_properties "$PWD" com.google.guava guava 33.7.2-jre
    write_pom_properties "$PWD" com.google.guava failureaccess 1.0.3
    verify_relocated_guava_closure org.apache.iceberg.relocated.com.google.common
}

patch_parquet_jar() {
    merge_jarjar_shaded_tree_jackson "$JACKSON_CORE" shaded/parquet/com/fasterxml/jackson/core
    merge_jarjar_shaded_tree_jackson "$JACKSON_DATABIND" shaded/parquet/com/fasterxml/jackson/databind
    merge_jarjar_shaded_tree_jackson "$JACKSON_ANNOTATIONS" shaded/parquet/com/fasterxml/jackson/annotation
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-core "${JACKSON_VERSION}"
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-databind "${JACKSON_VERSION}"

    verify_javap_contains shaded.parquet.com.fasterxml.jackson.core.JsonFactory \
        'this_class:' 'shaded/parquet/com/fasterxml/jackson/core/JsonFactory'
    verify_javap_contains shaded.parquet.com.fasterxml.jackson.databind.ObjectMapper \
        'this_class:' 'shaded/parquet/com/fasterxml/jackson/databind/ObjectMapper'

    local fdp="shaded/parquet/com/fasterxml/jackson/core/internal/shaded/fdp/${FDP_VERSION}"
    local entry
    for entry in \
        "${fdp}/FastDoubleSwar.class" \
        "META-INF/versions/11/${fdp}/BigSignificand.class" \
        "META-INF/versions/11/${fdp}/FastDoubleSwar.class" \
        "META-INF/versions/11/${fdp}/FastIntegerMath.class" \
        "META-INF/versions/17/${fdp}/FastDoubleSwar.class" \
        "META-INF/versions/17/${fdp}/FastIntegerMath.class" \
        "META-INF/versions/21/${fdp}/FastDoubleSwar.class" \
        "META-INF/versions/21/${fdp}/FastIntegerMath.class"
    do
        if [ ! -f "$entry" ]; then
            echo "missing relocated jackson ${JACKSON_VERSION} class: ${entry}" >&2
            exit 1
        fi
    done
}

guava_found=false
while IFS= read -r -d '' iceberg_jar; do
    guava_found=true
    echo "repacking shaded guava 33.7.2-jre in ${iceberg_jar}"
    repack_jar "$iceberg_jar" patch_iceberg_guava_jar
done < <(find "${JARS_ROOT}" -type f -name 'iceberg-bundled-guava-*.jar' -print0)

parquet_found=false
while IFS= read -r -d '' parquet_jar; do
    parquet_found=true
    echo "repacking shaded jackson ${JACKSON_VERSION} in ${parquet_jar}"
    repack_jar "$parquet_jar" patch_parquet_jar
done < <(find "${JARS_ROOT}" -type f \( -name 'parquet-hadoop-bundle-*.jar' -o -name 'parquet-jackson-*.jar' \) -print0)

if [ "$guava_found" != true ] && [ "$parquet_found" != true ]; then
    echo "no iceberg-bundled-guava or parquet bundle jars under ${JARS_ROOT}" >&2
    exit 1
fi

echo "shaded dependency remediation complete"
