#!/bin/sh
set -e

ulimit -c 0

# Because of the command use in the chart, with the chart command being in the middle of
# a complex command

if [ "$1" = 'server' ]; then
	set -- vault "$@"
fi

exec tini -- "$@"
