#!/bin/bash
NAME=$1
VERSION=$2

REGEX="([0-9]+\.[0-9]+\.[0-9]+)"
if [[ "$(grep $NAME pom.rb)" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
    CUR_VERSION="${BASH_REMATCH[0]}"
    if [[ "$(printf '%s\n' "$CUR_VERSION" "$VERSION" | sort -V | head -n1)" = "$CUR_VERSION" ]]; then
    sed -i "s/.*$NAME.*/  ['$NAME', '$VERSION'],/g" pom.rb
    fi
fi
