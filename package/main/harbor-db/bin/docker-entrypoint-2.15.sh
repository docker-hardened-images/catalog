#!/bin/bash
set -e

HARBOR_DB_HOME="${HARBOR_DB_HOME:-/usr/share/harbor-db}"

# If started as root (e.g. dev variant), re-exec this script as the postgres
# user via gosu. The exec replaces the current process; the new postgres-owned
# process falls through the id check below and runs the rest of the script.
if [ "$(id -u)" -eq 0 ]; then
        exec gosu postgres "$0" "$@"
fi

source "${HARBOR_DB_HOME}/initdb.sh"

CUR="${HARBOR_DB_HOME}"
PG_VERSION_OLD=$1
PG_VERSION_NEW=$2

PGBINOLD="/opt/postgresql/${PG_VERSION_OLD}/bin"
PGBINNEW="/opt/postgresql/${PG_VERSION_NEW}/bin"

PGDATAOLD=${PGDATA}/pg${PG_VERSION_OLD}
PGDATANEW=${PGDATA}/pg${PG_VERSION_NEW}

# We should block the upgrade path from 9.6 directly.
if [ -s $PGDATA/PG_VERSION ]; then
        echo "Upgrading from PostgreSQL 9.6 to PostgreSQL $PG_VERSION_NEW is not supported in the current Harbor release."
        echo "You should upgrade to previous Harbor firstly, then upgrade to current release."
        exit 1
fi

# Upgrade DB: 1. PG_NEW\PG_VERSION file doesn't exist and pg_old_parameter is not nil and PG_OLD\PG_VERSION file exist.
#             For example: ["15", "18"]
#             Harbor 2.15 upgrades an existing PostgreSQL 15 cluster to PostgreSQL 18.
# Init DB:    1. PG_NEW\PG_VERSION file doesn't exist and pg_old_parameter is not nil and PG_OLD\PG_VERSION file doesn't exist.
#             For example: ["15", "18"]
#             A new Harbor 2.15 installation initializes PostgreSQL 18.
#             2. PG_NEW\PG_VERSION file doesn't exist and pg_old_parameter is nil.
#             For example: ["", "18"]
#             ["", "18"] means database upgrade is not supported.
if [ ! -s $PGDATANEW/PG_VERSION ]; then
        if [ ! -z $PG_VERSION_OLD ] && [ -s $PGDATAOLD/PG_VERSION ]; then
                echo "upgrade DB from $PG_VERSION_OLD to $PG_VERSION_NEW"

                # PostgreSQL 18 enables data checksums by default, while clusters
                # created by earlier Harbor releases generally have them disabled.
                # pg_upgrade requires both clusters to use the same setting.
                if ! OLD_CONTROLDATA=$($PGBINOLD/pg_controldata "$PGDATAOLD" 2>/dev/null); then
                        echo "failed to determine old cluster checksum setting: pg_controldata failed"
                        exit 1
                fi
                if [[ "$OLD_CONTROLDATA" =~ Data\ page\ checksum\ version:[[:space:]]*([0-9]+) ]]; then
                        OLD_CHECKSUM_VERSION="${BASH_REMATCH[1]}"
                else
                        echo "failed to determine old cluster checksum setting: unexpected pg_controldata output"
                        exit 1
                fi
                if [ "$OLD_CHECKSUM_VERSION" = "0" ]; then
                        echo "old cluster has data checksums disabled, initializing new cluster with --no-data-checksums"
                        export POSTGRES_INITDB_ARGS="${POSTGRES_INITDB_ARGS} --no-data-checksums"
                fi

                initPG $PGDATANEW false
                set +e
                # In some cases, like helm upgrade, the postgresql may not quit cleanly.
                # Use start & stop to clean the unexpected status. Error:
                #   There seems to be a postmaster servicing the new cluster.
                #   Please shutdown that postmaster and try again.
                #   Failure, exiting
                $PGBINOLD/pg_ctl -D "$PGDATAOLD" -w -o "-p 5433" start
                $PGBINOLD/pg_ctl -D "$PGDATAOLD" -m fast -w stop
                "${CUR}/upgrade.sh" --old-bindir $PGBINOLD --new-bindir $PGBINNEW --old-datadir $PGDATAOLD --new-datadir $PGDATANEW
                # it needs to clean the $PGDATANEW on upgrade failure
                if [ $? -ne 0 ]; then
                        echo "remove the $PGDATANEW after fail to upgrade."
                        rm -rf $PGDATANEW
                        exit 1
                fi
                set -e
                echo "remove the $PGDATAOLD after upgrade success."
                rm -rf $PGDATAOLD
        else
                echo "init DB, DB version:$PG_VERSION_NEW"
                initPG $PGDATANEW true
        fi
fi

POSTGRES_PARAMETER=''
file_env 'POSTGRES_MAX_CONNECTIONS' '1024'
# The max value of 'max_connections' is 262143
if [ $POSTGRES_MAX_CONNECTIONS -le 0 ] || [ $POSTGRES_MAX_CONNECTIONS -gt 262143 ]; then
        POSTGRES_MAX_CONNECTIONS=262143
fi

POSTGRES_PARAMETER="${POSTGRES_PARAMETER} -c max_connections=${POSTGRES_MAX_CONNECTIONS}"
POSTGRES_PARAMETER="${POSTGRES_PARAMETER} -c listen_addresses=*"
exec postgres -D $PGDATANEW $POSTGRES_PARAMETER
