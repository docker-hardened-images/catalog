#!/bin/sh
set -e
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
srcdir="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp)"
sed \
  -e 's|^WHICH="which"|WHICH="/usr/bin/which"|' \
  -e 's|^AWK=$|AWK=/usr/bin/gawk|' \
  -e 's|^relpath=`dirname $0`|relpath="'"$srcdir"'"|' \
  -e '/^relpath=`(cd "\$relpath"; \/bin\/pwd)`/d' \
  "$srcdir/configure" > "$tmp"
chmod +x "$tmp"
cd "$srcdir"
exec "$tmp" "$@"
