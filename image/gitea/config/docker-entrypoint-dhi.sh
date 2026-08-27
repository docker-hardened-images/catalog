#!/bin/sh
set -eu

# gitea refuses to run as root; the dev variant runs as root per DHI
# convention, so drop to git before delegating to the upstream entrypoint.
if [ "$(id -u)" -eq 0 ]; then
	if command -v gosu >/dev/null 2>&1; then
		exec gosu git /usr/local/bin/docker-entrypoint.sh "$@"
	fi
	exec setpriv --reuid=1000 --regid=1000 --clear-groups /usr/local/bin/docker-entrypoint.sh "$@"
fi

exec /usr/local/bin/docker-entrypoint.sh "$@"
