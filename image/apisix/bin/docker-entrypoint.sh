#!/usr/bin/env bash

set -eo pipefail

if [ "$1" = "docker-start" ]; then
  if [ "$APISIX_STAND_ALONE" = "true" ]; then
    apisix init
  else
    apisix init
    apisix init_etcd
  fi

  exec openresty -p /usr/local/apisix -g 'daemon off;'
fi

exec "$@"
