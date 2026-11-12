#!/bin/sh
set -e

# Prevent core dumps
ulimit -c 0

set -- vault "$@"

if [ "$(id -u)" = '0' ]; then
	# Preserve cap_ipc_lock as a file capability if available
	if getpcaps 0 | grep "cap_ipc_lock"; then
		setcap cap_ipc_lock=+ep /usr/local/bin/vault
	else
		echo "Couldn't start vault with IPC_LOCK. Disabling IPC_LOCK, please use --cap-add IPC_LOCK"
	fi

	# Drop out of root
	set -- gosu vault "$@"
fi

exec tini -- "$@"
