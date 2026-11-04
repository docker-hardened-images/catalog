#!/bin/bash
# Replace the SCRAM 3.2 and stringprep 2.2 copies shaded into postgresql 42.7.14 with
# scram 3.3 / stringprep 2.4 (CVE-2026-53712). pgjdbc has no release that rebundles them yet.
# Bytecode is jarjar-relocated to org.postgresql.shaded.com.ongres.* (copying .class files alone
# leaves the internal name at com.ongres.* and breaks SCRAM auth).
set -euo pipefail

LIB_DIR="${1:?usage: patch-pgjdbc-shaded-scram.sh <lib/main-dir>}"
PATCH_DIR="${2:?usage: patch-pgjdbc-shaded-scram.sh <lib/main-dir> <patch-deps-dir>}"

SCRAM_CLIENT="${PATCH_DIR}/scram-client-3.3.jar"
SCRAM_COMMON="${PATCH_DIR}/scram-common-3.3.jar"
STRINGPREP="${PATCH_DIR}/stringprep-2.4.jar"
SASLPREP="${PATCH_DIR}/saslprep-2.4.jar"
JARJAR_CP="${PATCH_DIR}/jarjar-1.7.2.jar:${PATCH_DIR}/asm-7.0.jar:${PATCH_DIR}/asm-commons-7.0.jar"

for jar in "$SCRAM_CLIENT" "$SCRAM_COMMON" "$STRINGPREP" "$SASLPREP" \
    "${PATCH_DIR}/jarjar-1.7.2.jar" "${PATCH_DIR}/asm-7.0.jar" "${PATCH_DIR}/asm-commons-7.0.jar"; do
    if [ ! -f "$jar" ]; then
        echo "missing patch dependency: $jar" >&2
        exit 1
    fi
done

pg_jar="$(find "${LIB_DIR}" -maxdepth 1 -name 'org.postgresql.postgresql-42.7.*.jar' -print -quit)"
if [ -z "$pg_jar" ]; then
    echo "postgresql jdbc jar not found under ${LIB_DIR}" >&2
    exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

(cd "$work" && jar xf "$pg_jar")

rm -rf "$work/org/postgresql/shaded/com/ongres/scram"
rm -rf "$work/org/postgresql/shaded/com/ongres/stringprep"
rm -rf "$work/org/postgresql/shaded/com/ongres/saslprep"

copy_license_tree() {
    local from="$1"
    local to="$2"
    if [ ! -f "$work/META-INF/licenses/${from}/META-INF/LICENSE" ]; then
        echo "missing license tree ${from} in postgresql jar" >&2
        exit 1
    fi
    mkdir -p "$work/META-INF/licenses/${to}/META-INF"
    cp -a "$work/META-INF/licenses/${from}/META-INF/LICENSE" \
        "$work/META-INF/licenses/${to}/META-INF/LICENSE"
}

copy_license_tree "com.ongres.scram/scram-client-3.2" "com.ongres.scram/scram-client-3.3"
copy_license_tree "com.ongres.scram/scram-common-3.2" "com.ongres.scram/scram-common-3.3"
copy_license_tree "com.ongres.stringprep/stringprep-2.2" "com.ongres.stringprep/stringprep-2.4"
copy_license_tree "com.ongres.stringprep/saslprep-2.2" "com.ongres.stringprep/saslprep-2.4"

rm -rf "$work/META-INF/licenses/com.ongres.scram/scram-client-3.2"
rm -rf "$work/META-INF/licenses/com.ongres.scram/scram-common-3.2"
rm -rf "$work/META-INF/licenses/com.ongres.stringprep/stringprep-2.2"
rm -rf "$work/META-INF/licenses/com.ongres.stringprep/saslprep-2.2"

build_ongres_reloc_input() {
    local outjar="$1"
    local dep_work
    dep_work="$(mktemp -d)"
    (
        cd "$dep_work"
        for dep in "$SCRAM_CLIENT" "$SCRAM_COMMON" "$STRINGPREP" "$SASLPREP"; do
            jar xf "$dep"
        done
        jar cf "$outjar" .
    )
    rm -rf "$dep_work"
}

verify_javap_this_class() {
    local classname="$1"
    local expected_path="$2"
    local output
    local line

    if ! output="$(javap -verbose -classpath "$work" "$classname")"; then
        echo "javap failed for ${classname}" >&2
        return 1
    fi
    while IFS= read -r line; do
        case "$line" in
            *"this_class:"*"${expected_path}"*)
                return 0
                ;;
        esac
    done <<<"$output"
    echo "javap output for ${classname} missing this_class: ${expected_path}" >&2
    return 1
}

verify_scram_client_loadable() {
    local probe
    local probe_src

    probe="$(mktemp -d)"
    probe_src="${probe}/ScramClientLoadProbe.java"
    cat >"$probe_src" <<'EOF'
public class ScramClientLoadProbe {
    public static void main(String[] args) throws Exception {
        Class.forName("org.postgresql.shaded.com.ongres.scram.client.ScramClient");
    }
}
EOF
    if ! javac -cp "$work" -d "$probe" "$probe_src"; then
        echo "failed to compile ScramClient load probe" >&2
        rm -rf "$probe"
        return 1
    fi
    if ! java -cp "$work:$probe" ScramClientLoadProbe; then
        echo "Class.forName org.postgresql.shaded.com.ongres.scram.client.ScramClient failed" >&2
        rm -rf "$probe"
        return 1
    fi
    rm -rf "$probe"
}

install_jarjar_shaded_ongres() {
    local input
    local rules
    local out
    input="$(mktemp)"
    rules="$(mktemp)"
    out="$(mktemp -d)"
    build_ongres_reloc_input "$input"
    cat >"$rules" <<'EOF'
rule com.ongres.** org.postgresql.shaded.com.ongres.@1
EOF
    java -cp "$JARJAR_CP" org.pantsbuild.jarjar.Main process "$rules" "$input" "$out/relocated.jar"
    rm -f "$rules" "$input"
    (cd "$out" && jar xf relocated.jar)
    if [ ! -d "$out/org/postgresql/shaded/com/ongres" ]; then
        echo "jarjar output missing org/postgresql/shaded/com/ongres" >&2
        rm -rf "$out"
        exit 1
    fi
    mkdir -p "$work/org/postgresql/shaded/com"
    cp -a "$out/org/postgresql/shaded/com/ongres" "$work/org/postgresql/shaded/com/"
    rm -rf "$out"
}

install_jarjar_shaded_ongres

verify_javap_this_class "org.postgresql.shaded.com.ongres.scram.client.ScramClient" \
    "org/postgresql/shaded/com/ongres/scram/client/ScramClient"
verify_scram_client_loadable

rm -f "$pg_jar"
(cd "$work" && jar cMf "$pg_jar" .)

unzip -l "$pg_jar" "META-INF/licenses/com.ongres.scram/scram-client-3.3/*" >/dev/null
unzip -l "$pg_jar" "META-INF/licenses/com.ongres.scram/scram-common-3.3/*" >/dev/null
unzip -l "$pg_jar" "META-INF/licenses/com.ongres.stringprep/stringprep-2.4/*" >/dev/null
unzip -l "$pg_jar" "META-INF/licenses/com.ongres.stringprep/saslprep-2.4/*" >/dev/null
