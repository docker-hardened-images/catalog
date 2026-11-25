#!/usr/bin/env bash

set -eo pipefail

if [ "$1" = "docker-start" ]; then
  if [ "$APISIX_STAND_ALONE" = "true" ]; then
    apisix init
  else
    apisix init
    apisix init_etcd
  fi

  if [ -e "/usr/local/apisix/logs/worker_events.sock" ]; then
    rm -f "/usr/local/apisix/logs/worker_events.sock"
  fi

  if [ -e "/usr/local/apisix/logs/stream_worker_events.sock" ]; then
    rm -f "/usr/local/apisix/logs/stream_worker_events.sock"
  fi

  exec openresty -p /usr/local/apisix -g 'daemon off;'
fi

exec "$@"
