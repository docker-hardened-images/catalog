#!/bin/bash
# Post-install jar remediation for Spark package CVEs.
#
# Maven dependencyManagement pins do not reach shaded copies inside
# hadoop-client-runtime and parquet-jackson. This script replaces
# vulnerable loose jars and repacks shaded dependencies after
# make-distribution. Shaded Jetty stays in place, and Hive 2.3
# artifacts are left on the Hive profile Spark actually builds.
set -euo pipefail

if [ "${1:-}" != "--self-test" ]; then
    JARS_DIR="${1:?usage: remediate-jars.sh <jars-dir> <patch-deps-dir> <jackson-version>}"
    PATCH_DIR="${2:?usage: remediate-jars.sh <jars-dir> <patch-deps-dir> <jackson-version>}"
    JACKSON_VERSION="${3:?usage: remediate-jars.sh <jars-dir> <patch-deps-dir> <jackson-version>}"

    JACKSON_CORE="${PATCH_DIR}/jackson-core-${JACKSON_VERSION}.jar"
    JACKSON_DATABIND="${PATCH_DIR}/jackson-databind-${JACKSON_VERSION}.jar"
    JACKSON_ANNOTATIONS_VERSION="${JACKSON_VERSION}"
    if [ "${JACKSON_VERSION}" = "2.21.7" ]; then
        JACKSON_ANNOTATIONS_VERSION="2.21"
    fi
    JACKSON_ANNOTATIONS="${PATCH_DIR}/jackson-annotations-${JACKSON_ANNOTATIONS_VERSION}.jar"
    COMMONS_CONFIGURATION2="${PATCH_DIR}/commons-configuration2-2.15.0.jar"
    JLINE_REMOTE_TELNET="${PATCH_DIR}/jline-remote-telnet-4.2.1.jar"
    JLINE_UBER_JAR="${PATCH_DIR}/jline-3.30.17-jdk8.jar"
    JARJAR_JAR="${PATCH_DIR}/jarjar-assembly-1.14.1.jar"
    DERBY="${PATCH_DIR}/derby-10.17.1.0.jar"
    DERBYSHARED="${PATCH_DIR}/derbyshared-10.17.1.0.jar"
    DERBYTOOLS="${PATCH_DIR}/derbytools-10.17.1.0.jar"
    LIBTHRIFT="${PATCH_DIR}/libthrift-0.24.0.jar"
    COMMONS_LANG3="${PATCH_DIR}/commons-lang3-3.18.0.jar"
    NIMBUS_JOSE_JWT="${PATCH_DIR}/nimbus-jose-jwt-10.0.2.jar"
    GUAVA_JAR="${PATCH_DIR}/guava-33.7.2-jre.jar"
    FAILUREACCESS_JAR="${PATCH_DIR}/failureaccess-1.0.3.jar"
    KERBY_ASN1_JAR="${PATCH_DIR}/kerby-asn1-2.1.2.jar"

    for jar in \
        "$JACKSON_CORE" "$JACKSON_DATABIND" "$JACKSON_ANNOTATIONS" \
        "$COMMONS_CONFIGURATION2" "$JLINE_REMOTE_TELNET" "$JLINE_UBER_JAR" "$JARJAR_JAR" \
        "$DERBY" "$DERBYSHARED" "$DERBYTOOLS" "$LIBTHRIFT" \
        "$COMMONS_LANG3" "$NIMBUS_JOSE_JWT" "$GUAVA_JAR" "$FAILUREACCESS_JAR" "$KERBY_ASN1_JAR"; do
        if [ ! -f "$jar" ]; then
            echo "missing patch dependency: $jar" >&2
            exit 1
        fi
    done
fi

# Hadoop and Parquet shaded jars need jarjar so this_class matches the shaded
# package name; copying .class trees alone leaves the wrong internal names.
relocate_jarjar_tree() {
    local workdir="$1"
    local srcjar="$2"
    local destsub="$3"
    local rules_content="$4"
    local rules tmp unpacked
    rules="$(mktemp)"
    tmp="$(mktemp -d)"
    unpacked="$(mktemp -d)"
    printf '%s\n' "$rules_content" >"$rules"
    java -jar "$JARJAR_JAR" process "$rules" "$srcjar" "$tmp/reloc.jar"
    (cd "$unpacked" && jar xf "$tmp/reloc.jar")
    if [ ! -d "$unpacked/$destsub" ]; then
        echo "jarjar output missing ${destsub} from ${srcjar}" >&2
        exit 1
    fi
    rm -rf "${workdir}/${destsub}"
    find "${workdir}/META-INF/versions" -type d -path "*/${destsub}" -prune -exec rm -rf {} + 2>/dev/null || true
    mkdir -p "${workdir}/$(dirname "$destsub")"
    cp -a "$unpacked/$destsub" "${workdir}/${destsub}"
    for verpath in "$unpacked"/META-INF/versions/*/; do
        [ -d "$verpath" ] || continue
        ver="$(basename "$verpath")"
        if [ -d "$unpacked/META-INF/versions/$ver/$destsub" ]; then
            mkdir -p "${workdir}/META-INF/versions/$ver/$(dirname "$destsub")"
            cp -a "$unpacked/META-INF/versions/$ver/$destsub" "${workdir}/META-INF/versions/$ver/${destsub}"
        fi
    done
    rm -rf "$rules" "$tmp" "$unpacked"
}

# A databind-only rule leaves ObjectMapper extending the unshaded
# ObjectCodec. Hadoop and Parquet shaded copies extend the shaded
# ObjectCodec, so every Jackson input gets the core, databind, and
# annotations map.
jackson_relocation_rules() {
    local prefix="$1"
    printf '%s\n' \
        "rule com.fasterxml.jackson.core.** ${prefix}.com.fasterxml.jackson.core.@1" \
        "rule com.fasterxml.jackson.databind.** ${prefix}.com.fasterxml.jackson.databind.@1" \
        "rule com.fasterxml.jackson.annotation.** ${prefix}.com.fasterxml.jackson.annotation.@1"
}

assert_this_class() {
    local classname="$1"
    local expected
    expected="$(printf '%s' "$classname" | tr '.' '/')"
    if ! javap -verbose -classpath . "$classname" | grep -q "this_class:.*${expected}"; then
        echo "this_class is not ${expected} for ${classname}" >&2
        exit 1
    fi
}

# Type descriptors use slash form. Dotted strings such as the
# jackson groupId and optional-module coordinates are not descriptors.
assert_shaded_jackson_descriptors() {
    local mapper="$1"
    local codec="$2"
    local shade_path="$3"
    local header dir
    header="$(javap -classpath . "$mapper" | grep -m1 ' extends ' || true)"
    if ! printf '%s\n' "$header" | grep -F -q "extends ${codec}"; then
        echo "replaced ${mapper} superclass is not ${codec}: ${header}" >&2
        exit 1
    fi
    if printf '%s\n' "$header" | grep -E -q '(extends|implements) com\.fasterxml\.jackson\.'; then
        echo "unshaded jackson type in ${mapper}: ${header}" >&2
        exit 1
    fi
    dir="$(mktemp -d)"
    cat >"$dir/AssertShadedJackson.java" <<'EOF'
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.stream.Stream;

public class AssertShadedJackson {
    public static void main(String[] args) throws Exception {
        String shade = args[0];
        String slashPrefix = shade.endsWith("/") ? shade : shade + "/";
        List<String> bad = new ArrayList<String>();
        List<Path> roots = new ArrayList<Path>();
        roots.add(Paths.get(shade, "com", "fasterxml", "jackson"));
        Path versions = Paths.get("META-INF", "versions");
        if (Files.isDirectory(versions)) {
            try (Stream<Path> listed = Files.list(versions)) {
                Iterator<Path> it = listed.iterator();
                while (it.hasNext()) {
                    Path root = it.next().resolve(shade).resolve("com").resolve("fasterxml").resolve("jackson");
                    if (Files.isDirectory(root)) {
                        roots.add(root);
                    }
                }
            }
        }
        int checked = 0;
        for (Path root : roots) {
            if (!Files.isDirectory(root)) {
                System.err.println("missing shaded jackson tree: " + root);
                System.exit(1);
            }
            try (Stream<Path> walked = Files.walk(root)) {
                Iterator<Path> it = walked.iterator();
                while (it.hasNext()) {
                    Path path = it.next();
                    if (!path.toString().endsWith(".class")) {
                        continue;
                    }
                    checked++;
                    check(path, slashPrefix, bad);
                }
            }
        }
        if (!bad.isEmpty()) {
            for (String line : bad) {
                System.err.println(line);
            }
            System.exit(1);
        }
        if (checked == 0) {
            System.err.println("no shaded jackson classes under " + shade);
            System.exit(1);
        }
        System.out.println("shaded jackson descriptors ok: " + checked + " classes under " + shade);
    }

    static void check(Path path, String slashPrefix, List<String> bad) throws IOException {
        String latin = new String(Files.readAllBytes(path), StandardCharsets.ISO_8859_1);
        String needle = "com/fasterxml/jackson/";
        int from = 0;
        while (bad.size() < 8) {
            int i = latin.indexOf(needle, from);
            if (i < 0) {
                return;
            }
            int start = i - slashPrefix.length();
            if (start < 0 || !latin.regionMatches(start, slashPrefix, 0, slashPrefix.length())) {
                int a = Math.max(0, i - 48);
                int b = Math.min(latin.length(), i + 72);
                bad.add(path + ": " + latin.substring(a, b).replaceAll("[^\\p{Print}]", "."));
                return;
            }
            from = i + needle.length();
        }
    }
}
EOF
    javac -d "$dir" "$dir/AssertShadedJackson.java"
    java -cp "$dir" AssertShadedJackson "$shade_path"
    rm -rf "$dir"
    assert_this_class "${shade_path//\//.}.com.fasterxml.jackson.core.ObjectCodec"
    assert_this_class "${shade_path//\//.}.com.fasterxml.jackson.annotation.JsonInclude"
}

relocate_tree() {
    local workdir="$1"
    local srcjar="$2"
    local srcsub="$3"
    local destsub="$4"
    local tmp
    tmp="$(mktemp -d)"

    (cd "$tmp" && jar xf "$srcjar")

    rm -rf "${workdir}/${destsub}"
    find "${workdir}/META-INF/versions" -type d -path "*/${destsub}" -prune -exec rm -rf {} + 2>/dev/null || true

    mkdir -p "${workdir}/$(dirname "$destsub")"
    cp -a "$tmp/$srcsub" "${workdir}/${destsub}"

    for verpath in "$tmp"/META-INF/versions/*/; do
        [ -d "$verpath" ] || continue
        ver="$(basename "$verpath")"
        if [ -d "$tmp/META-INF/versions/$ver/$srcsub" ]; then
            mkdir -p "${workdir}/META-INF/versions/$ver/$(dirname "$destsub")"
            cp -a "$tmp/META-INF/versions/$ver/$srcsub" "${workdir}/META-INF/versions/$ver/${destsub}"
        fi
    done

    rm -rf "$tmp"
}

# Hadoop's hadoop-client-runtime shade relocates pattern org/ to
# org.apache.hadoop.shaded.org. and excludes slf4j. jarjar applies that
# relocation to the packages these JLine classes reference, rewriting
# this_class and constant-pool names. A path-only copy leaves org.jline.*
# and the JVM rejects the shaded path.
relocate_jline_jar() {
    local srcjar="$1"
    local outjar="$2"
    local rules
    rules="$(mktemp)"
    cat >"$rules" <<'EOF'
rule org.jline.** org.apache.hadoop.shaded.org.jline.@1
rule org.apache.sshd.** org.apache.hadoop.shaded.org.apache.sshd.@1
rule org.mozilla.** org.apache.hadoop.shaded.org.mozilla.@1
EOF
    java -jar "$JARJAR_JAR" process "$rules" "$srcjar" "$outjar"
    rm -f "$rules"
}

copy_relocated_tree() {
    local srcdir="$1"
    local destsub="$2"
    if [ ! -d "$srcdir" ]; then
        echo "missing relocated tree: $srcdir" >&2
        exit 1
    fi
    rm -rf "$destsub"
    find META-INF/versions -type d -path "*/${destsub}" -prune -exec rm -rf {} + 2>/dev/null || true
    mkdir -p "$(dirname "$destsub")"
    cp -a "$srcdir" "$(dirname "$destsub")/"
}

assert_shaded_class_loads() {
    local classname="$1"
    local dir
    dir="$(mktemp -d)"
    cat >"$dir/LoadShaded.java" <<'EOF'
public class LoadShaded {
    public static void main(String[] args) throws Exception {
        Class<?> loaded = Class.forName(args[0], false, ClassLoader.getSystemClassLoader());
        if (!loaded.getName().equals(args[0])) {
            throw new AssertionError(loaded.getName());
        }
    }
}
EOF
    javac -d "$dir" "$dir/LoadShaded.java"
    java -cp "$dir:." LoadShaded "$classname"
    rm -rf "$dir"
}

# JLine 3.30.17 reader calls terminal and utils APIs that Hadoop's shaded
# 3.9.0 copies do not have (RegexTimeoutException, MouseSupport.keys).
# Those packages have to move together. jline-native is new in this set;
# the 3.30 terminal references it.
JLINE_PACKAGES="reader builtins keymap style terminal utils nativ"

install_shaded_jline() {
    local uber_dir telnet_dir
    local prefix pkg reader builtins telnet
    local classfile base count
    uber_dir="$(mktemp -d)"
    telnet_dir="$(mktemp -d)"
    relocate_jline_jar "$JLINE_UBER_JAR" "$uber_dir/reloc.jar"
    relocate_jline_jar "$JLINE_REMOTE_TELNET" "$telnet_dir/reloc.jar"
    (cd "$uber_dir" && jar xf reloc.jar)
    (cd "$telnet_dir" && jar xf reloc.jar)

    prefix="org/apache/hadoop/shaded/org/jline"
    reader="${prefix}/reader"
    builtins="${prefix}/builtins"
    telnet="${prefix}/builtins/telnet"

    for pkg in $JLINE_PACKAGES; do
        copy_relocated_tree "$uber_dir/$prefix/$pkg" "$prefix/$pkg"
    done
    # The uber jar's builtins tree contains jline 3.30.17 telnet classes.
    # Replace that directory with relocated jline-remote-telnet 4.2.1.
    copy_relocated_tree "$telnet_dir/$telnet" "$telnet"
    # 3.9 registered JansiSupport and JnaSupport. 3.30 terminal no longer
    # ships those classes, so the old service files would point nowhere.
    # TerminalBuilder reads META-INF/jline/providers instead.
    rm -f \
        META-INF/services/org.apache.hadoop.shaded.org.jline.terminal.spi.JansiSupport \
        META-INF/services/org.apache.hadoop.shaded.org.jline.terminal.spi.JnaSupport
    install_relocated_jline_providers "$uber_dir"

    count=0
    for classfile in "$telnet_dir/$telnet"/*.class; do
        count=$((count + 1))
        base="$(basename "$classfile")"
        if ! cmp -s "$classfile" "$telnet/$base"; then
            echo "telnet class does not match jline-remote-telnet 4.2.1: $base" >&2
            exit 1
        fi
    done
    if [ "$count" -ne 18 ]; then
        echo "expected 18 jline-remote-telnet 4.2.1 classes, found $count" >&2
        exit 1
    fi
    if cmp -s "$uber_dir/$telnet/Telnet.class" "$telnet/Telnet.class"; then
        echo "installed telnet classes are still jline 3.30.17" >&2
        exit 1
    fi

    assert_shaded_class_loads org.apache.hadoop.shaded.org.jline.reader.LineReader
    assert_shaded_class_loads org.apache.hadoop.shaded.org.jline.builtins.telnet.Telnet
    assert_shaded_class_loads org.apache.hadoop.shaded.org.jline.utils.RegexTimeoutException
    if ! javap -verbose -classpath . org.apache.hadoop.shaded.org.jline.reader.LineReader \
        | grep -q 'this_class:.*org/apache/hadoop/shaded/org/jline/reader/LineReader'; then
        echo "LineReader this_class is not the Hadoop shaded name" >&2
        exit 1
    fi
    if ! javap -verbose -classpath . org.apache.hadoop.shaded.org.jline.builtins.telnet.Telnet \
        | grep -q 'this_class:.*org/apache/hadoop/shaded/org/jline/builtins/telnet/Telnet'; then
        echo "Telnet this_class is not the Hadoop shaded name" >&2
        exit 1
    fi
    assert_line_reader_builds

    rm -rf "$uber_dir" "$telnet_dir"
}

# Jarjar relocates provider classes but not the text records JLine 3.30
# reads at runtime. TerminalProvider.load looks up
# META-INF/jline/providers/<name> and instantiates the class named there.
# Those files still say org.jline.* after relocation, so TerminalBuilder
# reports "Unable to find terminal provider".
install_relocated_jline_providers() {
    local srcdir="$1"
    local name class relpath
    if [ ! -d "$srcdir/META-INF/jline/providers" ]; then
        echo "relocated jline jar is missing META-INF/jline/providers" >&2
        exit 1
    fi
    rm -rf META-INF/jline/providers
    mkdir -p META-INF/jline/providers
    for name in "$srcdir"/META-INF/jline/providers/*; do
        [ -f "$name" ] || continue
        name="$(basename "$name")"
        # One substitution. The replacement contains org.jline and must not
        # be rewritten again.
        sed 's/org\.jline\./org.apache.hadoop.shaded.org.jline./g' \
            "$srcdir/META-INF/jline/providers/$name" \
            >"META-INF/jline/providers/$name"
        if grep -E -q '^[[:space:]]*org\.jline\.' "META-INF/jline/providers/$name"; then
            echo "provider ${name} still names unshaded org.jline" >&2
            exit 1
        fi
        class="$(sed -n 's/^org\.apache\.hadoop\.shaded\.org\.jline\..*/&/p' \
            "META-INF/jline/providers/$name" | head -n 1)"
        if [ -z "$class" ]; then
            echo "provider ${name} has no shaded class name" >&2
            exit 1
        fi
        relpath="$(printf '%s' "$class" | tr '.' '/')"
        # The jdk8 uber jar publishes an ffm record whose class is not in
        # that jar. Copy the record either way, and require the class only
        # when the relocated jar actually contains it.
        if [ -f "$srcdir/${relpath}.class" ] && [ ! -f "${relpath}.class" ]; then
            echo "provider ${name} class was not copied: ${class}" >&2
            exit 1
        fi
    done
    for name in exec dumb; do
        if [ ! -s "META-INF/jline/providers/$name" ]; then
            echo "jline provider metadata is missing ${name}" >&2
            exit 1
        fi
        class="$(sed -n 's/^org\.apache\.hadoop\.shaded\.org\.jline\..*/&/p' \
            "META-INF/jline/providers/$name" | head -n 1)"
        relpath="$(printf '%s' "$class" | tr '.' '/')"
        if [ -z "$class" ] || [ ! -f "${relpath}.class" ]; then
            echo "provider ${name} class is not in the jar: ${class:-missing}" >&2
            exit 1
        fi
    done
}

# Loading LineReader is not enough. TerminalBuilder.system(false).dumb(true)
# discovers a provider from META-INF/jline/providers and will not construct
# DumbTerminal itself on that path. Empty streams keep the exec provider's
# input pump from reading a null stream; omitting them still builds, but the
# pump thread throws.
assert_line_reader_builds() {
    local dir
    dir="$(mktemp -d)"
    cat >"$dir/BuildLineReader.java" <<'EOF'
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import org.apache.hadoop.shaded.org.jline.reader.LineReader;
import org.apache.hadoop.shaded.org.jline.reader.LineReaderBuilder;
import org.apache.hadoop.shaded.org.jline.terminal.Terminal;
import org.apache.hadoop.shaded.org.jline.terminal.TerminalBuilder;

public class BuildLineReader {
    public static void main(String[] args) throws Exception {
        Terminal t = TerminalBuilder.builder()
                .system(false)
                .dumb(true)
                .streams(new ByteArrayInputStream(new byte[0]), new ByteArrayOutputStream())
                .build();
        LineReader reader = LineReaderBuilder.builder().terminal(t).build();
        if (reader == null) {
            throw new AssertionError("null line reader");
        }
        String terminalClass = t.getClass().getName();
        if (!terminalClass.startsWith("org.apache.hadoop.shaded.org.jline.")) {
            throw new AssertionError(terminalClass);
        }
        System.out.println("line reader constructed " + reader.getClass().getName()
                + " terminal " + terminalClass);
        t.close();
    }
}
EOF
    javac -cp . -d "$dir" "$dir/BuildLineReader.java"
    java -cp "$dir:." BuildLineReader
    rm -rf "$dir"
}

# CVE-2025-53864 is fixed in 9.37.4, every later 9.x, and every 10.0.2+.
# Hadoop 3.4 shades 9.37.2; Hadoop 3.5 (Spark 4.2) already shades 10.4.
# Replacing a fixed 9.x or 10.4 with 10.0.2 is a downgrade, so only a
# vulnerable embedded version is rewritten.
nimbus_version_vulnerable() {
    local ver="$1"
    local major minor patch
    if [ -z "$ver" ]; then
        return 1
    fi
    IFS=. read -r major minor patch <<<"${ver%%[^0-9.]*}"
    major="${major:-0}"
    minor="${minor:-0}"
    patch="${patch:-0}"
    if [ "$major" -gt 10 ]; then
        return 1
    fi
    if [ "$major" -eq 10 ]; then
        if [ "$minor" -gt 0 ] || [ "$patch" -ge 2 ]; then
            return 1
        fi
        return 0
    fi
    if [ "$major" -eq 9 ]; then
        if [ "$minor" -gt 37 ]; then
            return 1
        fi
        if [ "$minor" -eq 37 ] && [ "$patch" -ge 4 ]; then
            return 1
        fi
    fi
    return 0
}

# CVE-2026-102554 is fixed in Guava 33.7.2-jre. Hadoop shades an older copy inside
# hadoop-client-runtime; dependencyManagement bumps do not rewrite that jar.
guava_version_vulnerable() {
    local ver="$1"
    if [ -z "$ver" ] || [ "$ver" = "33.7.2-jre" ]; then
        return 1
    fi
    local base="${ver%%-jre}"
    local major minor patch
    IFS=. read -r major minor patch <<<"${base}"
    major="${major:-0}"
    minor="${minor:-0}"
    patch="${patch:-0}"
    if [ "$major" -lt 33 ]; then
        return 0
    fi
    if [ "$major" -gt 33 ]; then
        return 1
    fi
    if [ "$minor" -lt 7 ]; then
        return 0
    fi
    if [ "$minor" -gt 7 ]; then
        return 1
    fi
    if [ "$patch" -le 1 ]; then
        return 0
    fi
    return 1
}

# CVE-2026-57914 is fixed in kerby-asn1 2.1.2. Hadoop shades kerby-asn1 into
# hadoop-client-runtime; dependencyManagement bumps do not rewrite that copy.
kerby_asn1_version_vulnerable() {
    local ver="$1"
    local major minor patch
    if [ -z "$ver" ]; then
        return 1
    fi
    IFS=. read -r major minor patch <<<"${ver%%[^0-9.]*}"
    major="${major:-0}"
    minor="${minor:-0}"
    patch="${patch:-0}"
    if [ "$major" -gt 2 ]; then
        return 1
    fi
    if [ "$major" -lt 2 ]; then
        return 0
    fi
    if [ "$minor" -gt 1 ]; then
        return 1
    fi
    if [ "$minor" -lt 1 ]; then
        return 0
    fi
    if [ "$patch" -ge 2 ]; then
        return 1
    fi
    return 0
}

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
    (cd "$work" && jar cf "$jarpath" .)
    rm -rf "$work"
}

patch_hadoop_jar() {
    local rules
    rules="$(jackson_relocation_rules org.apache.hadoop.shaded)"
    relocate_jarjar_tree "$PWD" "$JACKSON_CORE" org/apache/hadoop/shaded/com/fasterxml/jackson/core "$rules"
    relocate_jarjar_tree "$PWD" "$JACKSON_DATABIND" org/apache/hadoop/shaded/com/fasterxml/jackson/databind "$rules"
    relocate_jarjar_tree "$PWD" "$JACKSON_ANNOTATIONS" org/apache/hadoop/shaded/com/fasterxml/jackson/annotation "$rules"
    assert_shaded_jackson_descriptors \
        org.apache.hadoop.shaded.com.fasterxml.jackson.databind.ObjectMapper \
        org.apache.hadoop.shaded.com.fasterxml.jackson.core.ObjectCodec \
        org/apache/hadoop/shaded
    relocate_jarjar_tree "$PWD" "$COMMONS_CONFIGURATION2" org/apache/hadoop/shaded/org/apache/commons/configuration2 \
        'rule org.apache.commons.configuration2.** org.apache.hadoop.shaded.org.apache.commons.configuration2.@1'
    install_shaded_jline
    relocate_jarjar_tree "$PWD" "$COMMONS_LANG3" org/apache/hadoop/shaded/org/apache/commons/lang3 \
        'rule org.apache.commons.lang3.** org.apache.hadoop.shaded.org.apache.commons.lang3.@1'
    nimbus_pom="META-INF/maven/com.nimbusds/nimbus-jose-jwt/pom.properties"
    nimbus_ver=""
    if [ -f "$nimbus_pom" ]; then
        nimbus_ver="$(sed -n 's/^version=//p' "$nimbus_pom" | head -n 1)"
    fi
    if nimbus_version_vulnerable "$nimbus_ver"; then
        echo "replacing shaded nimbus-jose-jwt ${nimbus_ver} with 10.0.2"
        relocate_jarjar_tree "$PWD" "$NIMBUS_JOSE_JWT" org/apache/hadoop/shaded/com/nimbusds \
            'rule com.nimbusds.** org.apache.hadoop.shaded.com.nimbusds.@1'
        write_pom_properties "$PWD" com.nimbusds nimbus-jose-jwt 10.0.2
    else
        echo "keeping shaded nimbus-jose-jwt ${nimbus_ver:-absent}"
    fi
    guava_pom="META-INF/maven/com.google.guava/guava/pom.properties"
    guava_ver=""
    if [ -f "$guava_pom" ]; then
        guava_ver="$(sed -n 's/^version=//p' "$guava_pom" | head -n 1)"
    fi
    if guava_version_vulnerable "$guava_ver"; then
        echo "replacing shaded guava ${guava_ver} with 33.7.2-jre"
        rm -rf org/apache/hadoop/shaded/com/google/common
        find META-INF/versions -type d -path '*/org/apache/hadoop/shaded/com/google/common' -prune -exec rm -rf {} + 2>/dev/null || true
        relocate_jarjar_tree "$PWD" "$GUAVA_JAR" org/apache/hadoop/shaded/com/google/common \
            'rule com.google.common.** org.apache.hadoop.shaded.com.google.common.@1'
        relocate_jarjar_tree "$PWD" "$FAILUREACCESS_JAR" org/apache/hadoop/shaded/com/google/common/util/concurrent/internal \
            'rule com.google.common.util.concurrent.internal.** org.apache.hadoop.shaded.com.google.common.util.concurrent.internal.@1'
        write_pom_properties "$PWD" com.google.guava guava 33.7.2-jre
        write_pom_properties "$PWD" com.google.guava failureaccess 1.0.3
    else
        echo "keeping shaded guava ${guava_ver:-absent}"
    fi
    kerby_pom="META-INF/maven/org.apache.kerby/kerby-asn1/pom.properties"
    kerby_ver=""
    if [ -f "$kerby_pom" ]; then
        kerby_ver="$(sed -n 's/^version=//p' "$kerby_pom" | head -n 1)"
    fi
    if kerby_asn1_version_vulnerable "$kerby_ver"; then
        echo "replacing shaded kerby-asn1 ${kerby_ver} with 2.1.2"
        relocate_jarjar_tree "$PWD" "$KERBY_ASN1_JAR" org/apache/hadoop/shaded/org/apache/kerby/asn1 \
            'rule org.apache.kerby.asn1.** org.apache.hadoop.shaded.org.apache.kerby.asn1.@1'
        # Take the artifact's own metadata so pom.xml and pom.properties both
        # say 2.1.2; a leftover 2.0.3 pom.xml would keep the old version visible.
        rm -rf META-INF/maven/org.apache.kerby/kerby-asn1
        jar xf "$KERBY_ASN1_JAR" META-INF/maven/org.apache.kerby/kerby-asn1
        grep -q '^version=2.1.2$' META-INF/maven/org.apache.kerby/kerby-asn1/pom.properties
    else
        echo "keeping shaded kerby-asn1 ${kerby_ver:-absent}"
    fi
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-core "${JACKSON_VERSION}"
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-databind "${JACKSON_VERSION}"
    write_pom_properties "$PWD" org.apache.commons commons-configuration2 2.15.0
    write_pom_properties "$PWD" org.apache.commons commons-lang3 3.18.0
    write_pom_properties "$PWD" org.jline jline 3.30.17
    write_pom_properties "$PWD" org.jline jline-reader 3.30.17
    write_pom_properties "$PWD" org.jline jline-builtins 3.30.17
    write_pom_properties "$PWD" org.jline jline-style 3.30.17
    write_pom_properties "$PWD" org.jline jline-terminal 3.30.17
    write_pom_properties "$PWD" org.jline jline-terminal-jansi 3.30.17
    write_pom_properties "$PWD" org.jline jline-terminal-jna 3.30.17
    write_pom_properties "$PWD" org.jline jline-terminal-jni 3.30.17
    write_pom_properties "$PWD" org.jline jline-native 3.30.17
    write_pom_properties "$PWD" org.jline jline-remote-telnet 4.2.1
    grep -q '^version=4.2.1$' META-INF/maven/org.jline/jline-remote-telnet/pom.properties
    grep -q '^version=3.30.17$' META-INF/maven/org.jline/jline-reader/pom.properties
    grep -q '^version=3.30.17$' META-INF/maven/org.jline/jline-builtins/pom.properties
    grep -q '^version=3.30.17$' META-INF/maven/org.jline/jline-terminal/pom.properties
    grep -q '^version=3.30.17$' META-INF/maven/org.jline/jline-native/pom.properties
}

patch_parquet_jar() {
    local rules
    rules="$(jackson_relocation_rules shaded.parquet)"
    relocate_jarjar_tree "$PWD" "$JACKSON_CORE" shaded/parquet/com/fasterxml/jackson/core "$rules"
    relocate_jarjar_tree "$PWD" "$JACKSON_DATABIND" shaded/parquet/com/fasterxml/jackson/databind "$rules"
    relocate_jarjar_tree "$PWD" "$JACKSON_ANNOTATIONS" shaded/parquet/com/fasterxml/jackson/annotation "$rules"
    assert_shaded_jackson_descriptors \
        shaded.parquet.com.fasterxml.jackson.databind.ObjectMapper \
        shaded.parquet.com.fasterxml.jackson.core.ObjectCodec \
        shaded/parquet
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-core "${JACKSON_VERSION}"
    write_pom_properties "$PWD" com.fasterxml.jackson.core jackson-databind "${JACKSON_VERSION}"
}

patch_spark_connect_guava_jar() {
    local guava_pom guava_ver failure_pom failure_ver rules
    guava_pom="META-INF/maven/com.google.guava/guava/pom.properties"
    guava_ver=""
    if [ -f "$guava_pom" ]; then
        guava_ver="$(sed -n 's/^version=//p' "$guava_pom" | head -n 1)"
    fi
    if ! guava_version_vulnerable "$guava_ver"; then
        echo "keeping spark connect guava ${guava_ver:-absent}"
        return 0
    fi
    echo "replacing spark connect guava ${guava_ver} with 33.7.2-jre"
    rm -rf org/sparkproject/connect/guava
    find META-INF/versions -type d -path '*/org/sparkproject/connect/guava' -prune -exec rm -rf {} + 2>/dev/null || true
    rules='rule com.google.common.** org.sparkproject.connect.guava.@1'
    relocate_jarjar_tree "$PWD" "$GUAVA_JAR" org/sparkproject/connect/guava "$rules"
    # The tree delete above removes relocated failureaccess classes, including
    # when the jar already records 1.0.3 or has no pom.properties. Always copy
    # the pinned tree. The recorded version only decides whether pom metadata
    # is rewritten.
    failure_pom="META-INF/maven/com.google.guava/failureaccess/pom.properties"
    failure_ver=""
    if [ -f "$failure_pom" ]; then
        failure_ver="$(sed -n 's/^version=//p' "$failure_pom" | head -n 1)"
    fi
    relocate_jarjar_tree "$PWD" "$FAILUREACCESS_JAR" org/sparkproject/connect/guava/util/concurrent/internal \
        'rule com.google.common.util.concurrent.internal.** org.sparkproject.connect.guava.util.concurrent.internal.@1'
    if [ -n "$failure_ver" ] && [ "$failure_ver" != "1.0.3" ]; then
        write_pom_properties "$PWD" com.google.guava failureaccess 1.0.3
    fi
    write_pom_properties "$PWD" com.google.guava guava 33.7.2-jre
}

strip_jline_telnet() {
    rm -rf org/jline/builtins/telnet
    rm -rf META-INF/maven/org.jline/jline-remote-telnet
}

replace_loose_jar() {
    local destname="$1"
    local srcjar="$2"
    install -T -m 0644 "$srcjar" "${JARS_DIR}/${destname}"
}

if [ "${1:-}" = "--self-test" ]; then
    fail=0
    expect_vulnerable() {
        if nimbus_version_vulnerable "$1"; then
            echo "vulnerable $1"
        else
            echo "expected vulnerable: $1" >&2
            fail=1
        fi
    }
    expect_fixed() {
        if nimbus_version_vulnerable "$1"; then
            echo "expected fixed: $1" >&2
            fail=1
        else
            echo "fixed $1"
        fi
    }
    expect_vulnerable 9.37.2
    expect_vulnerable 9.37.3
    expect_fixed 9.37.4
    expect_fixed 9.38.0
    expect_fixed 9.39.0
    expect_vulnerable 10.0.1
    expect_fixed 10.0.2
    expect_fixed 10.4
    if ! guava_version_vulnerable 32.0.1-jre; then fail=1; fi
    if ! guava_version_vulnerable 33.4.8-jre; then fail=1; fi
    if guava_version_vulnerable 33.7.2-jre; then fail=1; fi
    if ! kerby_asn1_version_vulnerable 2.0.3; then fail=1; fi
    if ! kerby_asn1_version_vulnerable 2.1.0; then fail=1; fi
    if ! kerby_asn1_version_vulnerable 2.1.1; then fail=1; fi
    if kerby_asn1_version_vulnerable 2.1.2; then fail=1; fi
    if kerby_asn1_version_vulnerable 2.2.0; then fail=1; fi
    if kerby_asn1_version_vulnerable 3.0.0; then fail=1; fi

    # Jarjar is stubbed so the failureaccess branch runs without dependency jars.
    # A replacement must recreate InternalFutureFailureAccess even when the
    # recorded failureaccess version is already 1.0.3 or the pom is absent.
    GUAVA_JAR="/self-test/guava-33.7.2-jre.jar"
    FAILUREACCESS_JAR="/self-test/failureaccess-1.0.3.jar"
    relocate_calls=0
    relocate_jarjar_tree() {
        local workdir="$1"
        local srcjar="$2"
        local destsub="$3"
        relocate_calls=$((relocate_calls + 1))
        rm -rf "${workdir}/${destsub}"
        mkdir -p "${workdir}/${destsub}"
        if [ "$srcjar" = "$FAILUREACCESS_JAR" ]; then
            : > "${workdir}/${destsub}/InternalFutureFailureAccess.class"
        fi
    }
    check_connect_failureaccess() {
        local label="$1"
        local guava_ver="$2"
        local failure_mode="$3"
        local expect_replace="$4"
        local work failure_pom class_path old_class
        work="$(mktemp -d)"
        mkdir -p "${work}/org/sparkproject/connect/guava/util/concurrent/internal"
        old_class="${work}/org/sparkproject/connect/guava/util/concurrent/internal/OldFailureAccess.class"
        : > "$old_class"
        mkdir -p "${work}/META-INF/maven/com.google.guava/guava"
        printf 'version=%s\n' "$guava_ver" > "${work}/META-INF/maven/com.google.guava/guava/pom.properties"
        failure_pom="${work}/META-INF/maven/com.google.guava/failureaccess/pom.properties"
        if [ "$failure_mode" != "omit" ]; then
            mkdir -p "$(dirname "$failure_pom")"
            printf 'version=%s\nkept=1\n' "$failure_mode" > "$failure_pom"
        fi
        relocate_calls=0
        pushd "$work" >/dev/null
        patch_spark_connect_guava_jar
        popd >/dev/null
        class_path="${work}/org/sparkproject/connect/guava/util/concurrent/internal/InternalFutureFailureAccess.class"
        if [ "$expect_replace" = "yes" ]; then
            if [ "$relocate_calls" -ne 2 ] || [ ! -f "$class_path" ]; then
                echo "expected failureaccess restore on ${label}: calls=${relocate_calls}" >&2
                fail=1
            fi
            if [ -f "$old_class" ]; then
                echo "old failureaccess class survived replacement on ${label}" >&2
                fail=1
            fi
            if [ "$failure_mode" = "omit" ]; then
                if [ -f "$failure_pom" ]; then
                    echo "omitted failureaccess pom was written on ${label}" >&2
                    fail=1
                fi
            elif [ "$failure_mode" = "1.0.3" ]; then
                if ! grep -q '^kept=1$' "$failure_pom" || ! grep -q '^version=1.0.3$' "$failure_pom"; then
                    echo "1.0.3 failureaccess pom was rewritten on ${label}" >&2
                    fail=1
                fi
            elif grep -q '^kept=1$' "$failure_pom" || ! grep -q '^version=1.0.3$' "$failure_pom"; then
                echo "failureaccess pom was not rewritten to 1.0.3 on ${label}" >&2
                fail=1
            fi
        else
            if [ "$relocate_calls" -ne 0 ] || [ ! -f "$old_class" ]; then
                echo "expected guava keep to skip failureaccess restore on ${label}" >&2
                fail=1
            fi
            if [ "$failure_mode" != "omit" ] && ! grep -q '^kept=1$' "$failure_pom"; then
                echo "failureaccess pom changed on keep path ${label}" >&2
                fail=1
            fi
        fi
        rm -rf "$work"
        echo "failureaccess ${label} checked"
    }
    check_connect_failureaccess "already-1.0.3" "33.4.8-jre" "1.0.3" "yes"
    check_connect_failureaccess "omitted-pom" "33.4.0-jre" "omit" "yes"
    check_connect_failureaccess "older-pom" "32.0.1-jre" "1.0.1" "yes"
    check_connect_failureaccess "fixed-guava" "33.7.2-jre" "1.0.1" "no"

    if [ "$fail" -ne 0 ]; then
        exit 1
    fi
    echo "nimbus version checks passed"
    echo "guava version checks passed"
    echo "kerby-asn1 version checks passed"
    echo "failureaccess restoration checks passed"
    exit 0
fi

echo "remediating loose jars in ${JARS_DIR}"

rm -f \
    "${JARS_DIR}/derby-10.16.1.1.jar" \
    "${JARS_DIR}/derbyshared-10.16.1.1.jar" \
    "${JARS_DIR}/derbytools-10.16.1.1.jar" \
    "${JARS_DIR}/libthrift-0.16.0.jar" \
    "${JARS_DIR}/libthrift-0.23.0.jar"
install -T -m 0644 "$DERBY" "${JARS_DIR}/derby-10.17.1.0.jar"
install -T -m 0644 "$DERBYSHARED" "${JARS_DIR}/derbyshared-10.17.1.0.jar"
install -T -m 0644 "$DERBYTOOLS" "${JARS_DIR}/derbytools-10.17.1.0.jar"
install -T -m 0644 "$LIBTHRIFT" "${JARS_DIR}/libthrift-0.24.0.jar"

HADOOP_JAR="$(find "${JARS_DIR}" -maxdepth 1 -name 'hadoop-client-runtime-*.jar' -print -quit)"
if [ -n "$HADOOP_JAR" ] && [ -f "$HADOOP_JAR" ]; then
    echo "repacking shaded dependencies in ${HADOOP_JAR}"
    repack_jar "$HADOOP_JAR" patch_hadoop_jar
fi

PARQUET_JAR="$(find "${JARS_DIR}" -maxdepth 1 -name 'parquet-jackson-*.jar' -print -quit)"
if [ -n "$PARQUET_JAR" ] && [ -f "$PARQUET_JAR" ]; then
    echo "repacking shaded jackson in ${PARQUET_JAR}"
    repack_jar "$PARQUET_JAR" patch_parquet_jar
fi

JLINE_UBER="$(find "${JARS_DIR}" -maxdepth 1 -name 'jline-*-jdk8.jar' -print -quit)"
if [ -n "$JLINE_UBER" ] && [ -f "$JLINE_UBER" ]; then
    destname="$(basename "$JLINE_UBER")"
    echo "replacing ${JLINE_UBER} with jline 3.30.17 (${destname})"
    replace_loose_jar "$destname" "$JLINE_UBER_JAR"
fi

while IFS= read -r -d '' CONNECT_JAR; do
    if [ -f "$CONNECT_JAR" ]; then
        echo "repacking spark connect guava in ${CONNECT_JAR}"
        repack_jar "$CONNECT_JAR" patch_spark_connect_guava_jar
    fi
done < <(find "${JARS_DIR}" \( -name 'spark-connect_*.jar' -o -path '*/connect-repl/spark-connect*.jar' \) -print0)

echo "jar remediation complete"
