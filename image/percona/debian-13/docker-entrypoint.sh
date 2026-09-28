#!/bin/bash
set -eo pipefail
shopt -s nullglob

if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

wantHelp=
for arg; do
	case "$arg" in
		-'?' | --help | --print-defaults | -V | --version)
			wantHelp=1
			break
			;;
	esac
done

if [ "$(id -u)" -eq 0 ]; then
	if command -v gosu > /dev/null 2>&1; then
		exec gosu mysql "$0" "$@"
	elif [ "$1" = 'mysqld' ] && [ -z "$wantHelp" ]; then
		set -- "$@" --user=mysql
	fi
fi

if [ -n "${DHI_MYSQL_FIPS:-}" ] && [ "$1" = 'mysqld' ]; then
	set -- "$@" --ssl-fips-mode=ON
fi

file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

process_init_file() {
	local f="$1"
	shift
	local mysql=("$@")

	case "$f" in
		*.sh)
			echo "$0: running $f"
			. "$f"
			;;
		*.sql)
			echo "$0: running $f"
			"${mysql[@]}" < "$f"
			echo
			;;
		*.sql.gz)
			echo "$0: running $f"
			gunzip -c "$f" | "${mysql[@]}"
			echo
			;;
		*) echo "$0: ignoring $f" ;;
	esac
	echo
}

_check_config() {
	local toRun=("$@" --verbose --help)
	local errors
	if ! errors="$("${toRun[@]}" 2>&1 > /dev/null)"; then
		cat >&2 <<-EOM

			ERROR: mysqld failed while attempting to check config
			command was: "${toRun[*]}"

			$errors
		EOM
		exit 1
	fi
}

_get_config() {
	local conf="$1"
	shift
	local line key value
	while IFS= read -r line; do
		case "$line" in
			[[:space:]]* | '') continue ;;
		esac
		key="${line%%[[:space:]]*}"
		[ "$key" = "$conf" ] || continue
		value="${line#*[[:space:]]}"
		value="${value#"${value%%[![:space:]]*}"}"
		printf '%s\n' "$value"
		return 0
	done < <("$@" --verbose --help --log-bin-index="$(mktemp -u)" 2> /dev/null)
}

_random_password() {
	head -c 512 /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | cut -c1-32
}

if [ "$1" = 'mysqld' ] && [ -z "$wantHelp" ]; then
	_check_config "$@"

	DATADIR="$(_get_config 'datadir' "$@")"

	if [ ! -d "$DATADIR/mysql" ]; then
		file_env 'MYSQL_ROOT_PASSWORD'
		if [ -z "$MYSQL_ROOT_PASSWORD" ] && [ -z "$MYSQL_ALLOW_EMPTY_PASSWORD" ] && [ -z "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			echo >&2 'error: database is uninitialized and password option is not specified'
			echo >&2 '  You need to specify one of MYSQL_ROOT_PASSWORD, MYSQL_ALLOW_EMPTY_PASSWORD and MYSQL_RANDOM_ROOT_PASSWORD'
			exit 1
		fi

		mkdir -p "$DATADIR"

		echo 'Initializing database'
		"$@" --initialize-insecure
		echo 'Database initialized'

		if command -v mysql_ssl_rsa_setup > /dev/null 2>&1 && [ ! -e "$DATADIR/server-key.pem" ]; then
			echo 'Initializing certificates'
			mysql_ssl_rsa_setup --datadir="$DATADIR"
			echo 'Certificates initialized'
		fi

		SOCKET="$(_get_config 'socket' "$@")"
		"$@" --skip-networking --socket="${SOCKET}" &
		pid="$!"

		mysql=(mysql --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" --password="")

		for i in {120..0}; do
			if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
				break
			fi
			echo 'MySQL init process in progress...'
			sleep 1
		done
		if [ "$i" = 0 ]; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		if [ -z "$MYSQL_INITDB_SKIP_TZINFO" ] && command -v mysql_tzinfo_to_sql > /dev/null 2>&1; then
			mysql_tzinfo_to_sql /usr/share/zoneinfo 2> /dev/null | "${mysql[@]}" mysql
		fi

		if [ -n "$MYSQL_RANDOM_ROOT_PASSWORD" ]; then
			MYSQL_ROOT_PASSWORD="$(_random_password)"
			echo "GENERATED ROOT PASSWORD: $MYSQL_ROOT_PASSWORD"
		fi

		rootCreate=
		file_env 'MYSQL_ROOT_HOST' '%'
		if [ -n "$MYSQL_ROOT_HOST" ] && [ "$MYSQL_ROOT_HOST" != 'localhost' ]; then
			read -r -d '' rootCreate <<-EOSQL || true
				CREATE USER 'root'@'${MYSQL_ROOT_HOST}' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
				GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION ;
			EOSQL
		fi

		"${mysql[@]}" <<-EOSQL
			SET @@SESSION.SQL_LOG_BIN=0;

			DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mysqlxsys', 'mysql.infoschema', 'mysql.session', 'root') OR host NOT IN ('localhost') ;
			ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' ;
			GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION ;
			${rootCreate}
			DROP DATABASE IF EXISTS test ;
			FLUSH PRIVILEGES ;
		EOSQL

		if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
			mysql+=(-p"${MYSQL_ROOT_PASSWORD}")
		fi

		file_env 'MYSQL_DATABASE'
		if [ -n "$MYSQL_DATABASE" ]; then
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` ;" | "${mysql[@]}"
			mysql+=("$MYSQL_DATABASE")
		fi

		file_env 'MYSQL_USER'
		file_env 'MYSQL_PASSWORD'
		if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
			echo "CREATE USER '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD' ;" | "${mysql[@]}"

			if [ -n "$MYSQL_DATABASE" ]; then
				echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' ;" | "${mysql[@]}"
			fi

			echo 'FLUSH PRIVILEGES ;' | "${mysql[@]}"
		fi

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			process_init_file "$f" "${mysql[@]}"
		done

		if [ -n "$MYSQL_ONETIME_PASSWORD" ]; then
			"${mysql[@]}" <<-EOSQL
				ALTER USER 'root'@'%' PASSWORD EXPIRE;
			EOSQL
		fi

		if ! kill -s TERM "$pid" || ! wait "$pid"; then
			echo >&2 'MySQL init process failed.'
			exit 1
		fi

		echo
		echo 'MySQL init process done. Ready for start up.'
		echo
	fi

	if [ -n "$MYSQL_INIT_ONLY" ]; then
		echo 'Initialization complete, now exiting!'
		exit 0
	fi
fi

exec "$@"
