#!/bin/bash
set -e

path_exist_in_env() {
  VALUE="$1"
  TARGETS="$2"
  OLD_IFS="$IFS"
  IFS=','
  for path in $TARGETS; do
    path="${path#"${path%%[![:space:]]*}"}"
    path="${path%"${path##*[![:space:]]}"}"
    if [ "$path" = "$VALUE" ]; then
      IFS="$OLD_IFS"
      return 1
    fi
  done
  IFS="$OLD_IFS"
  return 0
}

WILDCARD_TAIL_PATH="/var/log/containers/*.log"
IGNORE_TAIL_PATH="/var/log/containers/fluentd*.log"
if [[ -n "$FLUENT_CONTAINER_TAIL_PATH" ]]; then
  if [[ -n "${FLUENT_CONTAINER_TAIL_EXCLUDE_PATH}" ]]; then
    if path_exist_in_env "$IGNORE_TAIL_PATH" "$FLUENT_CONTAINER_TAIL_EXCLUDE_PATH"; then
      export FLUENT_CONTAINER_TAIL_EXCLUDE_PATH="$FLUENT_CONTAINER_TAIL_EXCLUDE_PATH,$IGNORE_TAIL_PATH"
    fi
  elif ! path_exist_in_env "$WILDCARD_TAIL_PATH" "$FLUENT_CONTAINER_TAIL_PATH"; then
    export FLUENT_CONTAINER_TAIL_EXCLUDE_PATH="$IGNORE_TAIL_PATH"
  fi
else
  if [[ -n "$FLUENT_CONTAINER_TAIL_EXCLUDE_PATH" ]]; then
    if path_exist_in_env "$IGNORE_TAIL_PATH" "$FLUENT_CONTAINER_TAIL_EXCLUDE_PATH"; then
      export FLUENT_CONTAINER_TAIL_EXCLUDE_PATH="$FLUENT_CONTAINER_TAIL_EXCLUDE_PATH,$IGNORE_TAIL_PATH"
    fi
  else
    export FLUENT_CONTAINER_TAIL_EXCLUDE_PATH="$IGNORE_TAIL_PATH"
  fi
fi

for plug in elasticsearch opensearch; do
  for snif in /usr/local/bundle/gems/fluent-plugin-${plug}-*/lib/fluent/plugin/${plug}_simple_sniffer.rb; do
    [[ -f $snif ]] && FLUENTD_OPT="${FLUENTD_OPT:+$FLUENTD_OPT }-r fluent/plugin/out_${plug} -r $snif"
  done
done

DEFAULT=/etc/default/fluentd
if [[ -r $DEFAULT ]]; then
  set -o allexport
  . $DEFAULT
  set +o allexport
fi

if [[ "${1#-}" != "$1" ]]; then
  set -- fluentd "$@"
fi

if [[ $1 = "fluentd" ]]; then
  shift
  set -- fluentd ${FLUENTD_OPT} "$@"

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
