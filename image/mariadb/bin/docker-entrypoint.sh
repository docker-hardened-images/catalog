#!/bin/bash
set -e

# Reexec as the mysql user if running as root.
if [ "$(id -u)" -eq 0 ]; then
	echo "ENTRYPOINT: Dropping root..."
	exec gosu mysql docker-entrypoint.sh "$@"
fi

file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local default="${2:-}"

	if [ -n "${!var:-}" ] && [ -n "${!fileVar:-}" ]; then
		cat >&2 <<-EOE
			ERROR: Both ${var} and ${fileVar} are set, but they are mutually exclusive options.
		EOE
		exit 1
	fi

	local value="$default"
	if [ -n "${!fileVar:-}" ]; then
		value="$(< "${!fileVar}")"
	elif [ -n "${!var:-}" ]; then
		value="${!var}"
	fi
	export "$var"="$value"
	unset "$fileVar"
}

# set MARIADB_xyz from MYSQL_xyz when MARIADB_xyz is unset
# and make them the same value (so user scripts can use either)
_mariadb_file_env() {
	local var="$1"; shift
	local maria="MARIADB_${var#MYSQL_}"
	file_env "$var" "$@"
	file_env "$maria" "${!var}"
	if [ "${!maria:-}" ]; then
		export "$var"="${!maria}"
	fi
}


# Check if the first argument is mariadbd (server mode)
if [ "$1" = "mariadbd" ]; then
  # Process MARIADB_ROOT_PASSWORD_FILE if set
  _mariadb_file_env 'MYSQL_ROOT_PASSWORD'
  # set MARIADB_ from MYSQL_ when it is unset and then make them the same value
  : "${MARIADB_OPTIONS:=${MYSQL_OPTIONS:-}}"

  # Server mode - check for password and initialize if needed
  if [ -z "$(ls -A "${MARIADB_DATA_DIR}" 2>/dev/null)" ]; then
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
      echo "MARIADB_ROOT_PASSWORD or MARIADB_ROOT_PASSWORD_FILE is not set. Exiting..."
      exit 1
    fi
    echo "Initializing database..."
    mariadb-install-db --auth-root-authentication-method=normal --datadir="${MARIADB_DATA_DIR}"
    echo "Starting database for initialization"
    mariadbd --skip-networking --datadir="${MARIADB_DATA_DIR}" &
    while ! test -S /run/mariadb/mariadb.sock; do
        sleep 1
    done
    echo "Configuring root users..."
    escaped_root_password="${MYSQL_ROOT_PASSWORD//\\/\\\\}"
    escaped_root_password="${escaped_root_password//\'/\'\'}"
    mariadb --protocol=socket -uroot <<-EOSQL
      SET autocommit = 1;
      SET @@SESSION.SQL_LOG_BIN = 0;

      ALTER USER 'root'@'localhost' IDENTIFIED BY '${escaped_root_password}';
      GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
      CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${escaped_root_password}';
      GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
      FLUSH PRIVILEGES;
EOSQL
    echo "Stopping database after initialization"
    MYSQL_PWD="${MYSQL_ROOT_PASSWORD}" mariadb-admin --protocol=socket shutdown -uroot
  fi
  # start the database
  echo "Starting database...."
  args=( "mariadbd" "--datadir=${MARIADB_DATA_DIR}" )
  # Append options only if we have some
  if [[ -n "${MARIADB_OPTIONS:-}" ]]; then
    # Split MARIADB_OPTIONS on whitespace into an array
    # This intentionally uses word splitting.
    # shellcheck disable=SC2206
    extra_opts=( $MARIADB_OPTIONS )
    args+=( "${extra_opts[@]}" )
  fi
  # Replace PID 1 with mysqld
  exec "${args[@]}"
else
  # Client mode or other commands - just execute them directly
  exec "$@"
fi
