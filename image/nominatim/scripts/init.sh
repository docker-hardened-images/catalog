#!/bin/bash
# First-start import, following mediagis/nominatim-docker init.sh. Runs as the
# image user against the embedded PostgreSQL, without sudo or service.
set -eo pipefail

source /app/postgres.sh

OSMFILE=${PROJECT_DIR}/data.osm.pbf

CURL=("curl" "-L" "-A" "${USER_AGENT}" "--fail-with-body")

if [ -z "$THREADS" ]; then
  THREADS=$(nproc)
fi

child_pid=

on_signal() {
  echo "Import interrupted, stopping" >&2
  if [ -n "${child_pid}" ]; then
    kill -TERM "${child_pid}" 2>/dev/null || true
    wait "${child_pid}" 2>/dev/null || true
  fi
  stop_postgres
  exit 143
}
trap on_signal TERM INT

# Run a long step in the background so a stop signal is handled while it runs.
run() {
  "$@" &
  child_pid=$!
  local rc=0
  wait "${child_pid}" || rc=$?
  child_pid=
  return "${rc}"
}

# mediagis fetches IMPORT_*=true files from a storage box it hosts. This image
# only accepts a path to a file you provide.
optional_file() {
  local name=$1 value=$2 target=$3 label=$4

  if [ "${value}" = "true" ]; then
    echo "${name}=true is not supported by this image: download the file, mount it, and set ${name} to its path" >&2
    exit 1
  elif [ -f "${value}" ]; then
    ln -sf "${value}" "${PROJECT_DIR}/${target}"
  else
    echo "Skipping optional ${label} import"
  fi
}

# https://nominatim.org/release-docs/5.3/admin/Import/#wikipediawikidata-rankings
optional_file IMPORT_WIKIPEDIA "${IMPORT_WIKIPEDIA}" wikimedia-importance.csv.gz "Wikipedia importance"
optional_file IMPORT_SECONDARY_WIKIPEDIA "${IMPORT_SECONDARY_WIKIPEDIA}" secondary_importance.sql.gz "Wikipedia secondary importance"
optional_file IMPORT_GB_POSTCODES "${IMPORT_GB_POSTCODES}" gb_postcodes.csv.gz "GB postcode"
optional_file IMPORT_US_POSTCODES "${IMPORT_US_POSTCODES}" us_postcodes.csv.gz "US postcode"
optional_file IMPORT_TIGER_ADDRESSES "${IMPORT_TIGER_ADDRESSES}" tiger-nominatim-preprocessed.csv.tar.gz "Tiger addresses"

if [ "$PBF_URL" != "" ]; then
  echo Downloading OSM extract from "$PBF_URL"
  run "${CURL[@]}" "$PBF_URL" -C - --create-dirs -o "$OSMFILE"
fi

if [ "$PBF_PATH" != "" ]; then
  echo Reading OSM extract from "$PBF_PATH"
  OSMFILE=$PBF_PATH
fi

if [ ! -f "${PGDATA}/PG_VERSION" ]; then
  # The builtin provider gives a UTF-8 C.UTF-8 locale without libc locale data.
  initdb -D "${PGDATA}" --username=nominatim --auth-local=trust --auth-host=scram-sha-256 \
    --encoding=UTF8 --locale=C --locale-provider=builtin --builtin-locale=C.UTF-8
  echo "include_dir = '${PG_CONF_DIR}/conf.d'" >> "${PGDATA}/postgresql.conf"
fi

# Import with fsync and full page writes off, as mediagis postgres-import.conf
# does. The server restarts with the normal settings once the import is done.
start_postgres -c fsync=off -c full_page_writes=off

psql -X -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='www-data'" | grep -q 1 || createuser -SDR www-data
set_role_passwords
psql -X -d postgres -c "DROP DATABASE IF EXISTS nominatim"

cd "${PROJECT_DIR}"

if [ "$REVERSE_ONLY" = "true" ]; then
  run nominatim import --osm-file "$OSMFILE" --threads "$THREADS" --reverse-only
else
  run nominatim import --osm-file "$OSMFILE" --threads "$THREADS"
fi

if [ -e tiger-nominatim-preprocessed.csv.tar.gz ]; then
  echo "Importing Tiger address data"
  run nominatim add-data --tiger-data tiger-nominatim-preprocessed.csv.tar.gz
fi

# Sometimes Nominatim marks parent places to be indexed during the initial
# import which leads to '123 entries are not yet indexed' errors in --check-database
# Thus another quick additional index here for the remaining places
run nominatim index --threads "$THREADS"

run nominatim admin --check-database

if [ "$REPLICATION_URL" != "" ]; then
  run nominatim replication --init
  if [ "$FREEZE" = "true" ]; then
    echo "Skipping freeze because REPLICATION_URL is not empty"
  fi
else
  if [ "$FREEZE" = "true" ]; then
    echo "Freezing database"
    run nominatim freeze
  fi
fi

export NOMINATIM_QUERY_TIMEOUT=600
export NOMINATIM_REQUEST_TIMEOUT=3600
if [ "$REVERSE_ONLY" = "true" ]; then
  run nominatim admin --warm --reverse
else
  run nominatim admin --warm
fi
export NOMINATIM_QUERY_TIMEOUT=10
export NOMINATIM_REQUEST_TIMEOUT=60

# gather statistics for query planner to potentially improve query performance
# see, https://github.com/osm-search/Nominatim/issues/1023
# and  https://github.com/osm-search/Nominatim/issues/1139
run psql -X -d nominatim -c "ANALYZE"

stop_postgres

echo "Deleting downloaded dumps in ${PROJECT_DIR}"
rm -f "${PROJECT_DIR}"/*sql.gz
rm -f "${PROJECT_DIR}"/*csv.gz
rm -f "${PROJECT_DIR}"/tiger-nominatim-preprocessed.csv.tar.gz

if [ "$PBF_URL" != "" ]; then
  rm -f "${OSMFILE}"
fi
