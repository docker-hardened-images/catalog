# PostgreSQL helpers shared by start.sh and init.sh. Sourced, not executed.

PG_CONF_DIR=/etc/postgresql/17/main
IMPORT_FINISHED=${PGDATA}/import-finished

postgres_pid=

# TCP is opened only when NOMINATIM_PASSWORD is set; otherwise the server
# listens on its Unix socket alone.
postgres_listen_addresses() {
  if [ -n "${NOMINATIM_PASSWORD}" ]; then
    echo '*'
  fi
}

# The image does not ship LLVM, so JIT is off.
start_postgres() {
  postgres -D "${PGDATA}" -c "listen_addresses=$(postgres_listen_addresses)" -c jit=off "$@" &
  postgres_pid=$!

  local i
  for i in $(seq 1 120); do
    if pg_isready -q -d postgres; then
      return 0
    fi
    if ! kill -0 "${postgres_pid}" 2>/dev/null; then
      echo "PostgreSQL failed to start" >&2
      postgres_pid=
      return 1
    fi
    sleep 1
  done

  echo "PostgreSQL did not accept connections within 120 seconds" >&2
  return 1
}

stop_postgres() {
  if [ -n "${postgres_pid}" ] && kill -0 "${postgres_pid}" 2>/dev/null; then
    # SIGINT is PostgreSQL's fast shutdown.
    kill -INT "${postgres_pid}"
    wait "${postgres_pid}" || true
  fi
  postgres_pid=
}

set_role_passwords() {
  if [ -z "${NOMINATIM_PASSWORD}" ]; then
    return 0
  fi

  psql -X -q -v ON_ERROR_STOP=1 -d postgres -v pw="${NOMINATIM_PASSWORD}" <<'SQL'
ALTER ROLE nominatim WITH PASSWORD :'pw';
ALTER ROLE "www-data" WITH PASSWORD :'pw';
SQL
}

allow_remote_password_login() {
  if [ -z "${NOMINATIM_PASSWORD}" ]; then
    return 0
  fi

  local rule='host all all all scram-sha-256'
  grep -qxF "${rule}" "${PGDATA}/pg_hba.conf" || echo "${rule}" >> "${PGDATA}/pg_hba.conf"
}
