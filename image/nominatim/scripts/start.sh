#!/bin/bash
# Container lifecycle, following mediagis/nominatim-docker start.sh: configure,
# import on first start, then run PostgreSQL and the gunicorn API side by side.
# The container stops when either process exits.
set -eo pipefail

source /app/postgres.sh

init_pid=
replication_pid=
gunicorn_pid=

stop_all() {
  trap - TERM INT
  if [ -n "${init_pid}" ]; then
    kill -TERM "${init_pid}" 2>/dev/null || true
    wait "${init_pid}" 2>/dev/null || true
  fi
  if [ -n "${replication_pid}" ]; then
    echo "Shutting down replication process"
    kill -TERM "${replication_pid}" 2>/dev/null || true
  fi
  if [ -n "${gunicorn_pid}" ]; then
    kill -TERM "${gunicorn_pid}" 2>/dev/null || true
    wait "${gunicorn_pid}" 2>/dev/null || true
  fi
  stop_postgres
}

on_signal() {
  stop_all
  exit 0
}
trap on_signal TERM INT

/app/config.sh

if [ "$(id -u)" = "0" ]; then
  echo "PostgreSQL does not run as root. Run the container as the image user, for example with --user 65532:65532" >&2
  exit 1
fi

if [ ! -f "${IMPORT_FINISHED}" ]; then
  /app/init.sh &
  init_pid=$!
  wait "${init_pid}"
  init_pid=
  touch "${IMPORT_FINISHED}"
fi

allow_remote_password_login
start_postgres
set_role_passwords

cd "${PROJECT_DIR}"
nominatim refresh --functions

# start continous replication process
if [ "$REPLICATION_URL" != "" ] && [ "$FREEZE" != "true" ]; then
  # run init in case replication settings changed
  nominatim replication --project-dir "${PROJECT_DIR}" --init
  if [ "$UPDATE_MODE" == "continuous" ]; then
    echo "starting continuous replication"
    nominatim replication --project-dir "${PROJECT_DIR}" &
    replication_pid=$!
  elif [ "$UPDATE_MODE" == "once" ]; then
    echo "starting replication once"
    nominatim replication --project-dir "${PROJECT_DIR}" --once &
    replication_pid=$!
  elif [ "$UPDATE_MODE" == "catch-up" ]; then
    echo "starting replication once in catch-up mode"
    nominatim replication --project-dir "${PROJECT_DIR}" --catch-up &
    replication_pid=$!
  else
    echo "skipping replication"
  fi
fi

if [ "$WARMUP_ON_STARTUP" = "true" ]; then
  export NOMINATIM_QUERY_TIMEOUT=600
  export NOMINATIM_REQUEST_TIMEOUT=3600
  if [ "$REVERSE_ONLY" = "true" ]; then
    echo "Warm database caches for reverse queries"
    nominatim admin --warm --reverse > /dev/null
  else
    echo "Warm database caches for search and reverse queries"
    nominatim admin --warm > /dev/null
  fi
  export NOMINATIM_QUERY_TIMEOUT=10
  export NOMINATIM_REQUEST_TIMEOUT=60
  echo "Warming finished"
else
  echo "Skipping cache warmup"
fi

# Set default number of workers if not specified
if [ -z "$GUNICORN_WORKERS" ]; then
  GUNICORN_WORKERS=$(nproc)
fi

echo "Starting Gunicorn with $GUNICORN_WORKERS workers"

echo "--> Nominatim is ready to accept requests"

# Nominatim 5.3 serves the Falcon ASGI app with gunicorn's asgi worker. The
# project directory must be the working directory.
/usr/lib/nominatim/bin/gunicorn \
  --bind 0.0.0.0:8080 \
  --workers "$GUNICORN_WORKERS" \
  --enable-stdio-inheritance \
  --worker-class asgi \
  "nominatim_api.server.falcon.server:run_wsgi()" &
gunicorn_pid=$!

rc=0
wait -n "${postgres_pid}" "${gunicorn_pid}" || rc=$?

if ! kill -0 "${postgres_pid}" 2>/dev/null; then
  echo "PostgreSQL exited unexpectedly" >&2
  postgres_pid=
else
  echo "Gunicorn exited unexpectedly" >&2
  gunicorn_pid=
fi
stop_all
if [ "${rc}" -eq 0 ]; then
  rc=1
fi
exit "${rc}"
