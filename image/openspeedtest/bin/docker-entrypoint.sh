#!/bin/sh
set -eu

conf=${CONFIG:-/etc/nginx/conf.d/OpenSpeedTest-Server.conf}

server_start=0
if [ "${1:-}" = "nginx" ] || [ "${1:-}" = "nginx-debug" ]; then
  server_start=1
  for arg in "$@"; do
    case "$arg" in
      -v|-V|-t|-T|-h)
        server_start=0
        ;;
    esac
  done
fi

if [ "$server_start" = 1 ] && [ ! -e /proc/net/if_inet6 ]; then
  tmp=$(mktemp)
  sed '/listen \[::\]/d' "$conf" > "$tmp"
  cat "$tmp" > "$conf"
  rm -f "$tmp"
fi

exec "$@"
