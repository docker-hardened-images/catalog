#!/usr/bin/env bash
# Collects the license material for every Go module linked into the keel binary,
# cross-checks the link set against the built binary's buildinfo, and writes
# THIRD-PARTY-NOTICES.txt. Fails loudly on any gap.
#
# Usage: go-notices.sh <source-dir> <built-binary> <notices-root> <build-tags> <ui-inventory-dir> <go-license-dir>
# The Go toolchain package does not ship LICENSE or PATENTS at GOROOT, so they come
# from <go-license-dir> (go-LICENSE and go-PATENTS, fetched and checksummed by the definition).
set -euo pipefail

src=$1
bin=$2
root=$3
tags=$4
inv=$5
golicense=$6

cd "$src"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Link set: one line per non-main module with linked packages.
# Fields: effective module path, effective version, module dir, package dir.
go list -deps -tags "$tags" -f \
  '{{if and .Module (not .Module.Main)}}{{$m := .Module}}{{with $m.Replace}}{{.Path}} {{.Version}}{{else}}{{$m.Path}} {{$m.Version}}{{end}} {{$m.Dir}} {{.Dir}}{{end}}' \
  ./cmd/keel | sort -u > "$work/link.txt"

if [ ! -s "$work/link.txt" ]; then
  echo "go-notices: empty link set" >&2
  exit 1
fi

awk '{print $1 "@" $2}' "$work/link.txt" | sort -u > "$work/want.txt"

# Buildinfo view of the shipped binary. Replacement lines (=>) override the dep line.
go version -m "$bin" | awk '
  function flush() { if (pend != "") print pend; pend = "" }
  $1 == "dep" { flush(); pend = $2 "@" $3; next }
  $1 == "=>" { pend = $2 "@" $3; flush(); next }
  { flush() }
  END { flush() }
' | sort -u > "$work/got.txt"

differences=$(comm -3 "$work/want.txt" "$work/got.txt")
if [ -n "$differences" ]; then
  echo "go-notices: go list link set differs from go version -m of $bin (comm -3: want-only, then got-only):" >&2
  echo "$differences" | head -40 >&2
  echo "go-notices: GOFLAGS=${GOFLAGS:-} GOPROXY=${GOPROXY:-} GOFIPS140=${GOFIPS140:-}" >&2
  go env GOFLAGS GOEXPERIMENT GOFIPS140 >&2
  exit 1
fi

# Go standard library license texts.
stdlib_dir="$root/go"
mkdir -p "$stdlib_dir"
cp --no-preserve=mode "$golicense/go-LICENSE" "$stdlib_dir/LICENSE"
cp --no-preserve=mode "$golicense/go-PATENTS" "$stdlib_dir/PATENTS"
test -s "$stdlib_dir/LICENSE"
test -s "$stdlib_dir/PATENTS"

# Per module: copy every license, copying, notice and patents file at each
# directory from the linked package up to the module root (never *.go).
while read -r mod ver mdir pdir; do
  [ -n "$mod" ] || continue
  dest="$root/go/$mod@$ver"
  found=0
  dir=$pdir
  while :; do
    rel=${dir#"$mdir"}
    rel=${rel#/}
    for f in "$dir"/*; do
      [ -f "$f" ] || continue
      base=$(basename "$f")
      case "$base" in *.go) continue ;; esac
      if printf '%s' "$base" | grep -Eqi '^(licen[cs]e|copying|notice|patents)'; then
        target="$dest${rel:+/$rel}"
        mkdir -p "$target"
        # Module cache files are read-only, and one file can be reached from several
        # packages, so copy with fresh (writable) modes.
        cp --no-preserve=mode "$f" "$target/$base"
        if printf '%s' "$base" | grep -Eqi '^(licen[cs]e|copying)'; then
          found=1
        fi
      fi
    done
    if [ "$dir" = "$mdir" ] || [ "$dir" = "/" ]; then
      break
    fi
    dir=$(dirname "$dir")
  done
  if [ "$found" -ne 1 ]; then
    echo "go-notices: no license file for $mod@$ver" >&2
    exit 1
  fi
done < "$work/link.txt"

# THIRD-PARTY-NOTICES.txt: one line per component, sorted, with the copied files.
modules=$(awk '{print $1 " " $2}' "$work/link.txt" | sort -u | wc -l)
{
  awk '{print $1 " " $2}' "$work/link.txt" | sort -u | while read -r mod ver; do
    [ -n "$mod" ] || continue
    dest="$root/go/$mod@$ver"
    files=$(cd "$dest" && find . -type f | sed 's#^\./##' | sort | paste -sd, -)
    printf 'go\t%s\t%s\tsee-files\t%s\n' "$mod" "$ver" "$files"
  done
  printf 'go\tstd\tgo%s\tBSD-3-Clause\tgo/LICENSE,go/PATENTS\n' "$(go env GOVERSION | sed 's/^go//')"
  if [ -s "$inv/ui-inventory.json" ]; then
    jq -r '.[] | ["npm", .name, .version, .license, ("npm/" + .name + "@" + .version)] | @tsv' "$inv/ui-inventory.json"
  fi
} | sort > "$root/THIRD-PARTY-NOTICES.txt"

npm_count=0
if [ -s "$inv/ui-inventory.json" ]; then
  npm_count=$(jq 'length' "$inv/ui-inventory.json")
fi
lines=$(wc -l < "$root/THIRD-PARTY-NOTICES.txt")
want_lines=$((npm_count + modules + 1))
if [ "$lines" -ne "$want_lines" ]; then
  echo "go-notices: THIRD-PARTY-NOTICES has $lines lines, want $want_lines" >&2
  exit 1
fi
echo "go-notices: $modules Go modules, $npm_count npm components, $lines notice lines"
