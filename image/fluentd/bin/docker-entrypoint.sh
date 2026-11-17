#!/bin/bash
set -e

# Preload jemalloc if exists
if [[ -f /usr/lib/libjemalloc/libjemalloc.so.2 ]]; then
  export LD_PRELOAD="/usr/lib/libjemalloc/libjemalloc.so.2${LD_PRELOAD:+:$LD_PRELOAD}"
fi


#source vars if file exists
DEFAULT=/etc/default/fluentd

if [[ -r $DEFAULT ]]; then
    set -o allexport
    . $DEFAULT
    set +o allexport
fi

# If the user has supplied only arguments append them to `fluentd` command
if [[ "${1#-}" != $1 ]]; then
    set -- fluentd "$@"
fi

# If user does not supply config file or plugins, use the default
if [[ $1 = "fluentd" ]]; then
    hasConfig=false
    hasPlugin=false

    for arg in "$@"; do
        if [[ $arg == "-c" || $arg == "--config" ]]; then
            hasConfig=true
        fi

        if [[ $arg == "-p" || $arg == "--plugin" ]]; then
           hasPlugin=true
        fi
    done

    if [[ $hasConfig = false ]]; then
        set -- "$@" --config /etc/fluent/fluent.conf
    fi

    if [[ $hasPlugin = false ]]; then
        set -- "$@" --plugin /etc/fluent/plugins
    fi

fi

exec "$@"
