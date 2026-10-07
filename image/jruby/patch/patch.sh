#!/bin/bash
# Bump a stdlib gem pinned in JRuby's lib/pom.rb to VERSION when the pinned
# version is older. Gems not listed in pom.rb (e.g. cgi on JRuby 10) are skipped.
set -euo pipefail

NAME=$1
VERSION=$2

for tool in grep sed sort head; do
    if ! command -v "$tool" > /dev/null; then
        echo "patch.sh: required tool '$tool' not found" >&2
        exit 1
    fi
done

if ! LINE="$(grep -E "^  \['$NAME', '[^']+'\],?$" pom.rb)"; then
    echo "patch.sh: $NAME not found in pom.rb, skipping" >&2
    exit 0
fi

if [[ "$LINE" =~ \'([0-9][0-9.]*)\'\] ]]; then
    CUR_VERSION="${BASH_REMATCH[1]}"
else
    echo "patch.sh: cannot parse version for $NAME from: $LINE" >&2
    exit 1
fi

if [[ "$(printf '%s\n' "$CUR_VERSION" "$VERSION" | sort -V | head -n1)" != "$CUR_VERSION" ]]; then
    echo "patch.sh: $NAME $CUR_VERSION is already newer than $VERSION, skipping" >&2
    exit 0
fi

sed -i "s/^  \['$NAME', '$CUR_VERSION'\]/  ['$NAME', '$VERSION']/" pom.rb

if ! grep -qE "^  \['$NAME', '$VERSION'\]" pom.rb; then
    echo "patch.sh: failed to update $NAME to $VERSION in pom.rb" >&2
    exit 1
fi

echo "patch.sh: $NAME $CUR_VERSION -> $VERSION"
