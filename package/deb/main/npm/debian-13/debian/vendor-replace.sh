#!/bin/sh
# Replace a vendored npm dependency with a specific version.
# Only upgrades — skips if the installed version is already >= the target.
# Usage: vendor-replace.sh <package> <version> <parent-node-modules-dir>
set -eu
pkg="$1"
ver="$2"
parent="$3"
dir="$parent/$pkg"
tarball="$(dirname "$0")/../../vendor/${pkg}-${ver}.tgz"

if [ ! -d "$dir" ]; then
  echo "vendor-replace: $dir does not exist, skipping"
  exit 0
fi

current=$(node -e "console.log(require('$dir/package.json').version)" 2>/dev/null || echo "0.0.0")

# Use node for semver comparison: exit 0 if current >= target (no upgrade needed)
if node -e "
  const c = '$current'.split('.').map(Number);
  const t = '$ver'.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if ((c[i]||0) > (t[i]||0)) process.exit(0);
    if ((c[i]||0) < (t[i]||0)) process.exit(1);
  }
  process.exit(0);
" 2>/dev/null; then
  echo "vendor-replace: $pkg $current >= $ver, skipping"
  exit 0
fi

echo "vendor-replace: bumping $pkg $current -> $ver"
rm -rf "$dir"
mkdir -p "$dir"
tar -xzf "$tarball" -C "$dir" --strip-components=1
