#!/bin/bash
set -e

# Reexec as the postgres user if running as root (dev variants); initdb
# refuses to run as root, so patroni could never bootstrap otherwise.
if [ "$(id -u)" -eq 0 ]; then
	echo "ENTRYPOINT: Dropping root..."
	exec gosu postgres docker-entrypoint.sh "$@"
fi

exec /opt/patroni/bin/patroni "$@"
