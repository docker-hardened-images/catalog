#!/bin/bash
# Replace every extract-zip install with the DHI-patched 2.0.2 tree
# (CVE-2026-56876 symlink target validation).
set -eux -o pipefail

PATCH_DIR="$1"
ROOT="$2"

replaced=0
while IFS= read -r -d '' pkg_dir; do
  echo "Replacing $pkg_dir"
  rm -rf "$pkg_dir"
  cp -a "$PATCH_DIR" "$pkg_dir"
  replaced=$((replaced + 1))
done < <(find "$ROOT" -type d -path '*/node_modules/extract-zip' -print0)

if [ "$replaced" -eq 0 ]; then
  echo "Error: no extract-zip paths found under $ROOT"
  exit 1
fi
echo "Patched extract-zip in $replaced location(s)"
