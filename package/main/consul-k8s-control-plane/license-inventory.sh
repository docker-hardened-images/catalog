#!/bin/bash
# Third-party license inventory for the Go binaries this package ships.
#
#   license-inventory.sh collect STAGE DATA FIRST_PARTY_LICENSE BINARY...
#     Records every dependency module@version that `go version -m` reports for each BINARY and copies that module's
#     license, notice and patents files out of the current GOMODCACHE into STAGE/third_party/<module>@<version>/.
#     A module replaced by another module uses the replacement's files. A module replaced by a local directory is
#     first-party and gets FIRST_PARTY_LICENSE. go/hermetic@v1 empties the module cache for each module graph, so
#     collect runs right after the builds of each graph.
#
#   license-inventory.sh check STAGE DATA OUT SOURCE
#     Classifies every collected file with trivy's embedded offline license classifier and fails unless every module
#     has a license file, every license found is in DATA/license-allowlist.txt, and the classifier agrees with the
#     module's row in DATA/licenses.tsv. Writes OUT/third_party/ and OUT/THIRD_PARTY_LICENSES.tsv, then checks that
#     the inventory rows equal the collected module set in both directions. SOURCE names where the source is.
#
# DATA/licenses.tsv:          module, SPDX expression. One file serves every leaf, so a module is its path; a
#                             module@version row wins over the path row for a version whose license files differ.
# DATA/license-allowlist.txt: one SPDX identifier per line.
# DATA/license-exceptions.tsv: module, file relative to the module root, SPDX expression; module is a path or a
#                              module@version. The expression is the reviewed license of that file and replaces the
#                              classifier for it. collect copies the file when the module root has no license file.
#                              Each row needs reviewer sign-off.
set -euo pipefail
export LC_ALL=C

die() {
	echo "license-inventory: $*" >&2
	exit 1
}

# Module cache paths encode each upper-case letter as "!" plus its lower-case form.
escape_path() {
	local s=$1 out="" c
	while [ -n "$s" ]; do
		c=${s:0:1}
		s=${s:1}
		case $c in
		[A-Z]) out+="!${c,,}" ;;
		*) out+=$c ;;
		esac
	done
	printf '%s' "$out"
}

# Prints "path<TAB>version<TAB>local-dir" for each dependency of a binary, after applying its replacement.
binary_deps() {
	go version -m "$1" | awk -F'\t' '
		function flush() { if (path != "") print path "\t" ver "\t" lcl; path = "" }
		$2 == "dep" { flush(); path = $3; ver = $4; lcl = ""; next }
		$2 == "=>" { if ($4 == "" || $3 ~ /^\.\.?\//) { lcl = $3 } else { path = $3; ver = $4 }; next }
		{ flush() }
		END { flush() }'
}

collect() {
	[ $# -ge 4 ] || die "usage: collect STAGE DATA FIRST_PARTY_LICENSE BINARY..."
	local stage=$1 data=$2 first_party=$3
	shift 3
	local exceptions=$data/license-exceptions.tsv
	[ -s "$first_party" ] || die "$first_party is missing or empty"
	[ -f "$exceptions" ] || die "$exceptions is missing"
	local modcache
	modcache=$(go env GOMODCACHE)
	[ -d "$modcache" ] || die "GOMODCACHE '$modcache' is not a directory"
	mkdir -p "$stage/third_party"
	touch "$stage/modules.tsv" "$stage/local.tsv"

	local bin name path ver lcl dest src file
	for bin in "$@"; do
		[ -x "$bin" ] || die "$bin is not an executable"
		name=$(basename "$bin")
		binary_deps "$bin" > "$stage/deps.tmp"
		test -s "$stage/deps.tmp" || die "$bin: go version -m lists no dependencies"
		while IFS=$'\t' read -r path ver lcl; do
			[ -n "$path" ] && [ -n "$ver" ] || die "$bin: unparsable dependency line"
			printf '%s\t%s\t%s\n' "$path" "$ver" "$name" >> "$stage/modules.tsv"
			dest=$stage/third_party/$path@$ver
			[ -d "$dest" ] && continue
			mkdir -p "$dest"
			if [ -n "$lcl" ]; then
				printf '%s\t%s\n' "$path" "$ver" >> "$stage/local.tsv"
				install -m 0644 "$first_party" "$dest/LICENSE"
				continue
			fi
			src=$modcache/$(escape_path "$path")@$ver
			test -d "$src" || die "$path@$ver: $src is not in the module cache"
			find "$src" -maxdepth 1 -type f \( -iname 'LICEN[CS]E*' -o -iname 'COPYING*' -o -iname 'NOTICE*' \
				-o -iname 'PATENTS*' -o -iname 'UNLICENSE*' \) -exec install -m 0644 {} "$dest/" \;
			if [ -z "$(ls -A "$dest")" ]; then
				file=$(awk -F'\t' -v p="$path" -v d="$path@$ver" '$1 == p || $1 == d { print $2; exit }' "$exceptions")
				if [ -n "$file" ]; then
					test -f "$src/$file" || die "$path@$ver: license-exceptions.tsv names $file, which does not exist"
					install -m 0644 "$src/$file" "$dest/"
				fi
			fi
		done < "$stage/deps.tmp"
		rm "$stage/deps.tmp"
	done
}

check() {
	[ $# -eq 4 ] || die "usage: check STAGE DATA OUT SOURCE"
	local stage=$1 data=$2 out=$3 source=$4
	local allow=$data/license-allowlist.txt pins=$data/licenses.tsv exceptions=$data/license-exceptions.tsv
	local f
	for f in "$stage/modules.tsv" "$allow" "$pins"; do
		[ -s "$f" ] || die "$f is missing or empty"
	done
	for f in "$exceptions" "$stage/local.tsv"; do
		[ -f "$f" ] || die "$f is missing"
	done

	sort -u "$stage/modules.tsv" > "$stage/modules.sorted"
	cut -f1,2 "$stage/modules.sorted" | sort -u > "$stage/expected.tsv"

	# trivy classifies a file only when its name looks like a license file, so each grant file is classified as
	# classify/<module>@<version>/<file>/LICENSE. NOTICE and PATENTS files are shipped but are not grants. A file
	# with a license-exceptions.tsv row is not classified; the row's identifiers stand in for it.
	local rel base reldir excepted
	rm -rf "$stage/classify"
	mkdir -p "$stage/classify" "$stage/trivy-cache"
	: > "$stage/excepted.tsv"
	(cd "$stage/third_party" && find . -type f | sed 's|^\./||') | while read -r rel; do
		base=${rel##*/}
		reldir=${rel%/*}
		excepted=$(awk -F'\t' -v p="${reldir%@*}" -v d="$reldir" -v f="$base" \
			'($1 == p || $1 == d) && $2 == f { print $3; exit }' "$exceptions")
		if [ -n "$excepted" ]; then
			printf '%s\n' $excepted | tr -d '()' | grep -vxE 'AND|OR|WITH|' |
				awk -v d="$reldir" '{ print d "\t" $0 }' >> "$stage/excepted.tsv"
			continue
		fi
		case "${base,,}" in
		licen[cs]e* | copying* | unlicense*) ;;
		*) continue ;;
		esac
		mkdir -p "$stage/classify/$rel"
		cp "$stage/third_party/$rel" "$stage/classify/$rel/LICENSE"
	done
	trivy fs --scanners license --license-full --offline-scan --skip-db-update --skip-java-db-update \
		--skip-check-update --skip-version-check --cache-dir "$stage/trivy-cache" --format json \
		--output "$stage/trivy.json" "$stage/classify" || die "trivy fs failed"
	[ -s "$stage/trivy.json" ] || die "trivy wrote no report"
	jq -r '.Results[]? | .Licenses[]? | [(.FilePath | sub("/[^/]+/LICENSE$"; "")), .Name] | @tsv' \
		"$stage/trivy.json" > "$stage/classified.tsv"
	cat "$stage/excepted.tsv" >> "$stage/classified.tsv"
	test -s "$stage/classified.tsv" || die "the classifier found no license in any module"

	local failures=$stage/failures.txt rows=$stage/rows.tsv mpl=$stage/mpl.txt
	: > "$failures"
	: > "$rows"
	: > "$mpl"
	local path ver dir files ids id got pinned want bins
	while IFS=$'\t' read -r path ver; do
		dir=$path@$ver
		files=$(ls -A "$stage/third_party/$dir" | paste -sd, -)
		if [ -z "$files" ]; then
			echo "$dir: no license file at the module root and no license-exceptions.tsv row" >> "$failures"
			continue
		fi
		ids=$(awk -F'\t' -v d="$dir" '$1 == d { print $2 }' "$stage/classified.tsv" | sort -u)
		if [ -z "$ids" ]; then
			echo "$dir: the classifier found no license in $files" >> "$failures"
			continue
		fi
		for id in $ids; do
			grep -qxF "$id" "$allow" || echo "$dir: $id is not in license-allowlist.txt" >> "$failures"
		done
		got=$(printf '%s\n' $ids | paste -sd' ' - | sed 's/ / AND /g')
		pinned=$(awk -F'\t' -v d="$dir" '$1 == d { print $2; exit }' "$pins")
		if [ -z "$pinned" ]; then
			pinned=$(awk -F'\t' -v p="$path" '$1 == p { print $2; exit }' "$pins")
		fi
		if [ -z "$pinned" ]; then
			printf '%s: not in licenses.tsv; the classifier found:\n%s\t%s\n' "$dir" "$path" "$got" >> "$failures"
			continue
		fi
		want=$(printf '%s\n' $pinned | tr -d '()' | grep -vxE 'AND|OR|WITH|' | sort -u)
		if [ "$want" != "$ids" ]; then
			echo "$dir: licenses.tsv says '$pinned', the classifier found '$got'" >> "$failures"
			continue
		fi
		bins=$(awk -F'\t' -v p="$path" -v v="$ver" '$1 == p && $2 == v { print $3 }' "$stage/modules.sorted" |
			sort -u | paste -sd, -)
		printf '%s\t%s\t%s\t%s\t%s\n' "$path" "$ver" "$bins" "$pinned" "$files" >> "$rows"
		if grep -qxF "$(printf '%s\t%s' "$path" "$ver")" "$stage/local.tsv"; then
			continue
		fi
		case " $want " in
		*" MPL-2.0 "*) echo "# https://proxy.golang.org/$(escape_path "$path")/@v/$ver.zip" >> "$mpl" ;;
		esac
	done < "$stage/expected.tsv"

	local pinned_path
	awk -F'\t' '!/^#/ && NF { sub(/@.*/, "", $1); print $1 }' "$pins" | sort -u | while read -r pinned_path; do
		cut -f1 "$stage/expected.tsv" | grep -qxF "$pinned_path" ||
			echo "license-inventory: warning: $pinned_path is in licenses.tsv but not compiled into this build" >&2
	done

	if [ -s "$failures" ]; then
		cat "$failures" >&2
		die "$(wc -l < "$failures") license problem(s); see above"
	fi

	mkdir -p "$out"
	local tsv=$out/THIRD_PARTY_LICENSES.tsv
	{
		echo "# Third-party Go modules compiled into: $(cut -f3 "$stage/modules.sorted" | sort -u | paste -sd' ' -)"
		echo "# Each module's license, notice and patents files are in third_party/<module>@<version>/."
		echo "# Source: $source"
		echo "# Source of each MPL-2.0 module:"
		cat "$mpl"
		printf 'module\tversion\tbinaries\tlicense\tfiles\n'
		cat "$rows"
	} > "$tsv"
	cp -R "$stage/third_party" "$out/third_party"

	awk -F'\t' '!/^#/ { print $1 "\t" $2 }' "$tsv" | tail -n +2 | sort -u > "$stage/inventory.tsv"
	diff "$stage/expected.tsv" "$stage/inventory.tsv" || die "THIRD_PARTY_LICENSES.tsv does not match the compiled modules"
	local dirs
	dirs=$(cd "$out/third_party" && find . -mindepth 1 -type f | sed 's|^\./||; s|/[^/]*$||' | sort -u | wc -l)
	[ "$dirs" -eq "$(wc -l < "$stage/expected.tsv")" ] || die "third_party/ does not hold one directory per module"
}

[ $# -ge 1 ] || die "usage: license-inventory.sh collect|check ..."
cmd=$1
shift
case $cmd in
collect) collect "$@" ;;
check) check "$@" ;;
*) die "unknown command: $cmd" ;;
esac
