#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
# or first arg is `something.conf`
if [ "${1#-}" != "$1" ] || [ "${1%.conf}" != "$1" ]; then
  set -- valkey-server "$@"
fi

# set an appropriate umask (if one isn't set)
um="$(umask)"
if [ "$um" = '0022' ]; then
  umask 0077
fi

MODULE_DIR="/usr/lib/valkey"
MODULE_ARGS=""
CONFIG=""

for arg in "$@"; do
  case "$arg" in
    *.conf) CONFIG="$arg" ;;
  esac
done

if [ "$1" = "valkey-server" ]; then
  for module in "$MODULE_DIR"/*.so; do
    [ -f "$module" ] || continue
    if [ -n "$CONFIG" ] && grep -q "loadmodule $module" "$CONFIG" 2>/dev/null; then
      continue
    fi
    MODULE_ARGS="$MODULE_ARGS --loadmodule $module"
  done
fi

exec "$@" $MODULE_ARGS $VALKEY_EXTRA_FLAGS
