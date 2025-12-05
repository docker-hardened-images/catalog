#!/bin/bash

set -e

# Check if the first argument is mysqld (server mode)
if [ "$1" = "mysqld" ]; then
  # Server mode - check for password and initialize if needed
  if [ -z "$(ls -A "${MYSQLDATA}" 2>/dev/null)" ]; then
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
      echo "MYSQL_ROOT_PASSWORD is not set. Exiting..."
      exit 1
    fi
    echo "ROOT: $MYSQL_ROOT_PASSWORD"
    echo "Initializing database..."
    mysqld --initialize-insecure --datadir="${MYSQLDATA}"
    echo "Starting database for initialization"
    mysqld --daemonize --datadir="${MYSQLDATA}"
    echo "Creating root user..."
    mysql -uroot <<<"CREATE USER 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'; GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION ;"
    echo "Stopping database after initialization"
    mysqladmin shutdown -uroot
  fi
  # start the database
  echo "Starting database...."
  args=( "mysqld" "--datadir=${MYSQLDATA}" )
  # Append options only if we have some
  if [[ -n "${MYSQL_OPTIONS:-}" ]]; then
    # Split MYSQL_OPTIONS on whitespace into an array
    # This intentionally uses word splitting.
    # shellcheck disable=SC2206
    extra_opts=( $MYSQL_OPTIONS )
    args+=( "${extra_opts[@]}" )
  fi
  # Replace PID 1 with mysqld
  exec "${args[@]}"
else
  # Client mode or other commands - just execute them directly
  exec "$@"
fi
