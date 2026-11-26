#!/usr/bin/env bash
# Stage the licence and notice files for a set of kaniko binaries.
#
# Usage: stage-licenses.sh DEST ECR_SRC PACKAGE=BINARY...
#
# Run from the kaniko module root. DEST is the licence directory to fill
# (for example ${target.dir}/usr/share/licenses/kaniko). ECR_SRC is the
# amazon-ecr-credential-helper checkout, or "-" when no PACKAGE is the ECR
# helper. Each PACKAGE is a Go main package and BINARY is the runtime binary
# built from it; the module set staged here must equal the one recorded in
# the binaries, or the script fails.
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 DEST ECR_SRC PACKAGE=BINARY..." >&2
  exit 2
fi

dest=$1
ecr_src=$2
shift 2

main_module=$(go list -m)
[ "$main_module" = "github.com/chainguard-dev/kaniko" ]
test -s vendor/modules.txt

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$dest"

# The prefixes `go mod vendor` treats as module metadata.
is_meta() {
  local name=${1,,}
  case "$name" in
    *.go | *.s | *.c | *.h) return 1 ;;
  esac
  case "$name" in
    license* | licence* | copying* | copyright* | notice* | patents* | authors* | contributors* | legal* | copyleft*) return 0 ;;
  esac
  return 1
}

: > "$work/packages.txt"
: > "$work/binary-modules.txt"
ecr_wanted=false
for pair in "$@"; do
  pkg=${pair%%=*}
  bin=${pair#*=}
  test -x "$bin"
  case "$pkg" in
    github.com/awslabs/amazon-ecr-credential-helper/*) ecr_wanted=true ;;
  esac

  go list -deps -f '{{if .Module}}{{if not .Module.Main}}{{.Dir}}|{{.Module.Path}}|{{.Module.Version}}{{end}}{{end}}' "$pkg" >> "$work/packages.txt"

  go version -m "$bin" > "$work/buildinfo.txt"
  if grep -qE '^[[:space:]]+=>' "$work/buildinfo.txt"; then
    echo "$bin: replaced modules in build info" >&2
    exit 1
  fi
  awk -v main="$main_module" '($1 == "mod" || $1 == "dep") && $2 != main {print $2, $3}' "$work/buildinfo.txt" >> "$work/binary-modules.txt"
done

LC_ALL=C sort -u -o "$work/packages.txt" "$work/packages.txt"
LC_ALL=C sort -u -o "$work/binary-modules.txt" "$work/binary-modules.txt"
awk -F'|' '{print $2, $3}' "$work/packages.txt" | LC_ALL=C sort -u > "$work/listed-modules.txt"
test -s "$work/listed-modules.txt"

if ! LC_ALL=C cmp -s "$work/listed-modules.txt" "$work/binary-modules.txt"; then
  echo "go list -deps and go version -m disagree on the linked modules:" >&2
  LC_ALL=C diff "$work/listed-modules.txt" "$work/binary-modules.txt" >&2 || true
  exit 1
fi

# Every module must be vendored at the version the binary records.
while read -r mod ver; do
  grep -qxF "# $mod $ver" vendor/modules.txt || {
    echo "$mod $ver is not in vendor/modules.txt" >&2
    exit 1
  }
  test -d "vendor/$mod"
done < "$work/binary-modules.txt"

# Walk from each linked package directory up to its module root and stage the
# metadata files found on the way.
cwd=$(pwd)
declare -A seen=()
: > "$work/staged.txt"
while IFS='|' read -r dir mod _; do
  root=$cwd/vendor/$mod
  case "$dir" in
    "$root" | "$root"/*) ;;
    *)
      echo "package dir $dir is outside vendor/$mod" >&2
      exit 1
      ;;
  esac
  d=$dir
  while [ -z "${seen[$d]:-}" ]; do
    seen[$d]=1
    for f in "$d"/*; do
      [ -f "$f" ] || continue
      is_meta "${f##*/}" || continue
      echo "$mod|${f#"$root/"}" >> "$work/staged.txt"
    done
    [ "$d" = "$root" ] && break
    d=${d%/*}
  done
done < "$work/packages.txt"
LC_ALL=C sort -u -o "$work/staged.txt" "$work/staged.txt"

while IFS='|' read -r mod f; do
  install -D -m 0644 "vendor/$mod/$f" "$dest/vendor/$mod/$f"
done < "$work/staged.txt"

# Every linked module carries a licence text, and no NOTICE in a linked
# module's vendor tree is left behind.
: > "$dest/INVENTORY"
while read -r mod ver; do
  files=$(awk -F'|' -v m="$mod" '$1 == m {print $2}' "$work/staged.txt" | paste -sd, -)
  if ! printf '%s\n' "$files" | tr ',' '\n' | awk -F/ '{print tolower($NF)}' | grep -qE '^(license|licence|copying|copyright)'; then
    echo "$mod $ver: no licence file staged" >&2
    exit 1
  fi
  printf '%s %s %s\n' "$mod" "$ver" "$files" >> "$dest/INVENTORY"
done < "$work/binary-modules.txt"

while read -r mod _; do
  find "vendor/$mod" -type f -iname 'notice*' | while read -r n; do
    test -f "$dest/$n" || {
      echo "$n is not staged" >&2
      exit 1
    }
  done
done < "$work/binary-modules.txt"

# The main module's own texts, and the in-tree code with separate notices.
install -D -m 0644 LICENSE "$dest/LICENSE"
install -D -m 0644 third_party/moby/LICENSE "$dest/third_party/moby/LICENSE"
install -D -m 0644 third_party/moby/NOTICE "$dest/third_party/moby/NOTICE"
grep -q 'Docker, Inc' "$dest/third_party/moby/NOTICE"
for pair in "$@"; do
  case "${pair%%=*}" in
    ./third_party/docker-credential-acr-env)
      install -D -m 0644 third_party/docker-credential-acr-env/LICENSE "$dest/third_party/docker-credential-acr-env/LICENSE"
      install -D -m 0644 third_party/docker-credential-acr-env/PATCHES.md "$dest/third_party/docker-credential-acr-env/PATCHES.md"
      ;;
  esac
done

# The ECR helper's repository-root notices sit outside its Go module.
if [ "$ecr_wanted" = true ]; then
  [ "$ecr_src" != "-" ]
  ecr_mod=github.com/awslabs/amazon-ecr-credential-helper/ecr-login
  [ "$(awk '$1 == "module" {print $2; exit}' "$ecr_src/ecr-login/go.mod")" = "$ecr_mod" ]
  ecr_ver=$(awk -v m="$ecr_mod" '$1 == m {print $2; exit}' "$work/binary-modules.txt")
  [ -n "$ecr_ver" ]
  grep -qxF "# $ecr_mod $ecr_ver" vendor/modules.txt
  [ "v${ECR_LOGIN_VERSION:?}" = "$ecr_ver" ]
  install -D -m 0644 "$ecr_src/NOTICE" "$dest/amazon-ecr-credential-helper/NOTICE"
  install -D -m 0644 "$ecr_src/THIRD-PARTY-LICENSES" "$dest/amazon-ecr-credential-helper/THIRD-PARTY-LICENSES"
elif [ "$ecr_src" != "-" ]; then
  echo "ECR_SRC given but no ECR helper package listed" >&2
  exit 1
fi

LC_ALL=C sort -o "$dest/INVENTORY" "$dest/INVENTORY"
echo "staged $(wc -l < "$dest/INVENTORY") modules and $(wc -l < "$work/staged.txt") vendored files into $dest"
