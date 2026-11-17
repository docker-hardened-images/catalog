#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Derived from percona/percona-docker percona-server-mongodb-7.0/ps-entry.sh.
# Adapted for the hardened image: no telemetry agent; server telemetry stays off unless PERCONA_TELEMETRY_DISABLE=0.
set -Eeuo pipefail

if [ "${1:0:1}" = '-' ]; then
	set -- mongod "$@"
fi

originalArgOne="$1"

if [[ "$originalArgOne" == mongo* ]] && [ "$(id -u)" = '0' ]; then
	if [ "$originalArgOne" = 'mongod' ]; then
		if [ -d "/data/configdb" ]; then
			find /data/configdb \! -user mongodb -exec chown mongodb '{}' +
		fi
		if [ -d "/data/db" ]; then
			find /data/db \! -user mongodb -exec chown mongodb '{}' +
		fi
	fi

	chown --dereference mongodb "/proc/$$/fd/1" "/proc/$$/fd/2" || :

	exec gosu mongodb:1001 "$BASH_SOURCE" "$@"
fi

if [[ "$originalArgOne" == mongo* ]]; then
	numa='numactl --interleave=all'
	if $numa true &> /dev/null; then
		set -- $numa "$@"
	fi
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

_mongod_hack_have_arg() {
	local checkArg="$1"; shift
	local arg
	for arg; do
		case "$arg" in
			"$checkArg"|"$checkArg"=*)
				return 0
				;;
		esac
	done
	return 1
}

_mongod_hack_get_arg_val() {
	local checkArg="$1"; shift
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		case "$arg" in
			"$checkArg")
				echo "$1"
				return 0
				;;
			"$checkArg"=*)
				echo "${arg#$checkArg=}"
				return 0
				;;
		esac
	done
	return 1
}

declare -a mongodHackedArgs

_mongod_hack_ensure_arg() {
	local ensureArg="$1"; shift
	mongodHackedArgs=( "$@" )
	if ! _mongod_hack_have_arg "$ensureArg" "$@"; then
		mongodHackedArgs+=( "$ensureArg" )
	fi
}

_mongod_hack_ensure_no_arg() {
	local ensureNoArg="$1"; shift
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		if [ "$arg" = "$ensureNoArg" ]; then
			continue
		fi
		mongodHackedArgs+=( "$arg" )
	done
}

_mongod_hack_ensure_no_arg_val() {
	local ensureNoArg="$1"; shift
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		case "$arg" in
			"$ensureNoArg")
				shift
				continue
				;;
			"$ensureNoArg"=*)
				continue
				;;
		esac
		mongodHackedArgs+=( "$arg" )
	done
}

_mongod_hack_ensure_arg_val() {
	local ensureArg="$1"; shift
	local ensureVal="$1"; shift
	_mongod_hack_ensure_no_arg_val "$ensureArg" "$@"
	mongodHackedArgs+=( "$ensureArg" "$ensureVal" )
}

_mongod_hack_rename_arg_save_val() {
	local oldArg="$1"; shift
	local newArg="$1"; shift
	if ! _mongod_hack_have_arg "$oldArg" "$@"; then
		return 0
	fi
	local val=""
	mongodHackedArgs=()
	while [ "$#" -gt 0 ]; do
		local arg="$1"; shift
		if [ "$arg" = "$oldArg" ]; then
			val="$1"; shift
			continue
		elif [[ "$arg" =~ "$oldArg"=(.*) ]]; then
			val=${BASH_REMATCH[1]}
			continue
		fi
		mongodHackedArgs+=("$arg")
	done
	mongodHackedArgs+=("$newArg" "$val")
}

_mongod_hack_rename_arg() {
	local oldArg="$1"; shift
	local newArg="$1"; shift
	if _mongod_hack_have_arg "$oldArg" "$@"; then
		_mongod_hack_ensure_no_arg "$oldArg" "$@"
		_mongod_hack_ensure_arg "$newArg" "${mongodHackedArgs[@]}"
	fi
}

_js_escape() {
	jq --null-input --arg 'str' "$1" '$str'
}

jsonConfigFile="${TMPDIR:-/tmp}/docker-entrypoint-config.json"
tempConfigFile="${TMPDIR:-/tmp}/docker-entrypoint-temp-config.json"
_parse_config() {
	if [ -s "$tempConfigFile" ]; then
		return 0
	fi

	local configPath
	if configPath="$(_mongod_hack_get_arg_val --config "$@")"; then
		mongosh --norc --nodb --quiet --eval "load('/js-yaml.js'); JSON.stringify(jsyaml.load(fs.readFileSync($(_js_escape "$configPath"), 'utf8')))" > "$jsonConfigFile"
		jq '
			del(.systemLog, .processManagement, .net, .replication)
			| if .security then
				.security |= with_entries(
					select(.key == "enableEncryption" or .key == "encryptionKeyFile" or .key == "encryptionCipherMode" or .key == "vault" or .key == "kmip")
				)
				| if .security == {} then del(.security) else . end
			  else .
			  end
		' "$jsonConfigFile" > "$tempConfigFile"
		return 0
	fi

	return 1
}

dbPath=
_dbPath() {
	if [ -n "$dbPath" ]; then
		echo "$dbPath"
		return
	fi

	if ! dbPath="$(_mongod_hack_get_arg_val --dbpath "$@")"; then
		if _parse_config "$@"; then
			dbPath="$(jq -r '.storage.dbPath // empty' "$jsonConfigFile")"
		fi
	fi

	: "${dbPath:=/data/db}"

	echo "$dbPath"
}

if [ "$originalArgOne" = 'mongod' ]; then
	file_env 'MONGO_INITDB_ROOT_USERNAME'
	file_env 'MONGO_INITDB_ROOT_PASSWORD'
	shouldPerformInitdb=
	if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
		_mongod_hack_ensure_arg '--auth' "$@"
		set -- "${mongodHackedArgs[@]}"
		shouldPerformInitdb='true'
	elif [ "$MONGO_INITDB_ROOT_USERNAME" ] || [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
		cat >&2 <<-'EOF'

			error: missing 'MONGO_INITDB_ROOT_USERNAME' or 'MONGO_INITDB_ROOT_PASSWORD'
			       both must be specified for a user to be created

		EOF
		exit 1
	fi

	if [ -z "$shouldPerformInitdb" ]; then
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh|*.js)
					shouldPerformInitdb="$f"
					break
					;;
			esac
		done
	fi

	if [ -n "$shouldPerformInitdb" ]; then
		dbPath="$(_dbPath "$@")"
		for path in \
			"$dbPath/WiredTiger" \
			"$dbPath/journal" \
			"$dbPath/local.0" \
			"$dbPath/storage.bson" \
		; do
			if [ -e "$path" ]; then
				shouldPerformInitdb=
				break
			fi
		done
	fi

	if [ -n "$shouldPerformInitdb" ]; then
		mongodHackedArgs=( "$@" )
		if _parse_config "$@"; then
			_mongod_hack_ensure_arg_val --config "$tempConfigFile" "${mongodHackedArgs[@]}"
		fi
		_mongod_hack_ensure_arg_val --bind_ip 127.0.0.1 "${mongodHackedArgs[@]}"
		_mongod_hack_ensure_arg_val --port 27017 "${mongodHackedArgs[@]}"
		_mongod_hack_ensure_no_arg --bind_ip_all "${mongodHackedArgs[@]}"

		_mongod_hack_ensure_no_arg --auth "${mongodHackedArgs[@]}"
		if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
			_mongod_hack_ensure_no_arg_val --replSet "${mongodHackedArgs[@]}"
		fi

		tlsMode='disabled'
		if _mongod_hack_have_arg '--tlsCertificateKeyFile' "${mongodHackedArgs[@]}"; then
			tlsMode='preferTLS'
		elif _mongod_hack_have_arg '--sslPEMKeyFile' "${mongodHackedArgs[@]}"; then
			tlsMode='preferSSL'
		fi
		if [ "$tlsMode" = 'preferTLS' ] || mongod --help 2>&1 | grep -q -- ' --tlsMode '; then
			_mongod_hack_ensure_arg_val --tlsMode "$tlsMode" "${mongodHackedArgs[@]}"
		else
			_mongod_hack_ensure_arg_val --sslMode "$tlsMode" "${mongodHackedArgs[@]}"
		fi

		if stat "/proc/$$/fd/1" > /dev/null && [ -w "/proc/$$/fd/1" ]; then
			_mongod_hack_ensure_arg_val --logpath "/proc/$$/fd/1" "${mongodHackedArgs[@]}"
		else
			initdbLogPath="$(_dbPath "$@")/docker-initdb.log"
			echo >&2 "warning: initdb logs cannot write to '/proc/$$/fd/1', so they are in '$initdbLogPath' instead"
			_mongod_hack_ensure_arg_val --logpath "$initdbLogPath" "${mongodHackedArgs[@]}"
		fi
		_mongod_hack_ensure_arg --logappend "${mongodHackedArgs[@]}"

		pidfile="${TMPDIR:-/tmp}/docker-entrypoint-temp-mongod.pid"
		rm -f "$pidfile"
		_mongod_hack_ensure_arg_val --pidfilepath "$pidfile" "${mongodHackedArgs[@]}"

		"${mongodHackedArgs[@]}" --fork

		mongo=( mongosh --host 127.0.0.1 --port 27017 --quiet )

		tries=30
		while true; do
			if ! { [ -s "$pidfile" ] && ps "$(< "$pidfile")" &> /dev/null; }; then
				echo >&2
				echo >&2 "error: $originalArgOne does not appear to have stayed running -- perhaps it had an error?"
				echo >&2
				exit 1
			fi
			if "${mongo[@]}" 'admin' --eval 'quit(0)' &> /dev/null; then
				break
			fi
			(( tries-- ))
			if [ "$tries" -le 0 ]; then
				echo >&2
				echo >&2 "error: $originalArgOne does not appear to have accepted connections quickly enough -- perhaps it had an error?"
				echo >&2
				exit 1
			fi
			sleep 1
		done

		if [ "$MONGO_INITDB_ROOT_USERNAME" ] && [ "$MONGO_INITDB_ROOT_PASSWORD" ]; then
			rootAuthDatabase='admin'

			"${mongo[@]}" "$rootAuthDatabase" <<-EOJS
				db.createUser({
					user: $(_js_escape "$MONGO_INITDB_ROOT_USERNAME"),
					pwd: $(_js_escape "$MONGO_INITDB_ROOT_PASSWORD"),
					roles: [ { role: 'root', db: $(_js_escape "$rootAuthDatabase") } ]
				})
			EOJS
		fi

		export MONGO_INITDB_DATABASE="${MONGO_INITDB_DATABASE:-test}"

		echo
		for f in /docker-entrypoint-initdb.d/*; do
			case "$f" in
				*.sh) echo "$0: running $f"; . "$f" ;;
				*.js) echo "$0: running $f"; "${mongo[@]}" "$MONGO_INITDB_DATABASE" "$f"; echo ;;
				*)    echo "$0: ignoring $f" ;;
			esac
			echo
		done

		"${mongodHackedArgs[@]}" --shutdown
		rm -f "$pidfile"

		echo
		echo 'MongoDB init process complete; ready for start up.'
		echo
	fi

	mongodHackedArgs=("$@")
	MONGO_SSL_DIR=${MONGO_SSL_DIR:-/etc/mongodb-ssl}
	CA=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
	if [ -f /var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt ]; then
		CA=/var/run/secrets/kubernetes.io/serviceaccount/service-ca.crt
	fi
	if [ -f "${MONGO_SSL_DIR}/ca.crt" ]; then
		CA="${MONGO_SSL_DIR}/ca.crt"
	fi
	if [ -f "${MONGO_SSL_DIR}/tls.key" ] && [ -f "${MONGO_SSL_DIR}/tls.crt" ]; then
		cat "${MONGO_SSL_DIR}/tls.key" "${MONGO_SSL_DIR}/tls.crt" >/tmp/tls.pem
		_mongod_hack_ensure_arg_val --sslPEMKeyFile /tmp/tls.pem "${mongodHackedArgs[@]}"
		if [ -f "${CA}" ]; then
			_mongod_hack_ensure_arg_val --sslCAFile "${CA}" "${mongodHackedArgs[@]}"
		fi
	fi
	MONGO_SSL_INTERNAL_DIR=${MONGO_SSL_INTERNAL_DIR:-/etc/mongodb-ssl-internal}
	if [ -f "${MONGO_SSL_INTERNAL_DIR}/tls.key" ] && [ -f "${MONGO_SSL_INTERNAL_DIR}/tls.crt" ]; then
		cat "${MONGO_SSL_INTERNAL_DIR}/tls.key" "${MONGO_SSL_INTERNAL_DIR}/tls.crt" >/tmp/tls-internal.pem
		_mongod_hack_ensure_arg_val --sslClusterFile /tmp/tls-internal.pem "${mongodHackedArgs[@]}"
		if [ -f "${MONGO_SSL_INTERNAL_DIR}/ca.crt" ]; then
			_mongod_hack_ensure_arg_val --sslClusterCAFile "${MONGO_SSL_INTERNAL_DIR}/ca.crt" "${mongodHackedArgs[@]}"
		fi
	fi

	_mongod_hack_rename_arg_save_val --sslMode --tlsMode "${mongodHackedArgs[@]}"

	if _mongod_hack_have_arg '--tlsMode' "${mongodHackedArgs[@]}"; then
		tlsMode="none"
		if _mongod_hack_have_arg 'allowSSL' "${mongodHackedArgs[@]}"; then
			tlsMode='allowTLS'
		elif _mongod_hack_have_arg 'preferSSL' "${mongodHackedArgs[@]}"; then
			tlsMode='preferTLS'
		elif _mongod_hack_have_arg 'requireSSL' "${mongodHackedArgs[@]}"; then
			tlsMode='requireTLS'
		fi

		if [ "$tlsMode" != "none" ]; then
			_mongod_hack_ensure_no_arg_val --tlsMode "${mongodHackedArgs[@]}"
			_mongod_hack_ensure_arg_val --tlsMode "$tlsMode" "${mongodHackedArgs[@]}"
		fi
	fi

	_mongod_hack_rename_arg_save_val --sslPEMKeyFile --tlsCertificateKeyFile "${mongodHackedArgs[@]}"
	if ! _mongod_hack_have_arg '--tlsMode' "${mongodHackedArgs[@]}"; then
		if _mongod_hack_have_arg '--tlsCertificateKeyFile' "${mongodHackedArgs[@]}"; then
			_mongod_hack_ensure_arg_val --tlsMode "preferTLS" "${mongodHackedArgs[@]}"
		fi
	fi
	_mongod_hack_rename_arg '--sslAllowInvalidCertificates' '--tlsAllowInvalidCertificates' "${mongodHackedArgs[@]}"
	_mongod_hack_rename_arg '--sslAllowInvalidHostnames' '--tlsAllowInvalidHostnames' "${mongodHackedArgs[@]}"
	_mongod_hack_rename_arg '--sslAllowConnectionsWithoutCertificates' '--tlsAllowConnectionsWithoutCertificates' "${mongodHackedArgs[@]}"
	_mongod_hack_rename_arg '--sslFIPSMode' '--tlsFIPSMode' "${mongodHackedArgs[@]}"

	_mongod_hack_rename_arg_save_val --sslPEMKeyPassword --tlsCertificateKeyFilePassword "${mongodHackedArgs[@]}"
	_mongod_hack_rename_arg_save_val --sslClusterFile --tlsClusterFile "${mongodHackedArgs[@]}"
	_mongod_hack_rename_arg_save_val --sslCertificateSelector --tlsCertificateSelector "${mongodHackedArgs[@]}"
	_mongod_hack_rename_arg_save_val --sslClusterCertificateSelector --tlsClusterCertificateSelector "${mongodHackedArgs[@]}"
	_mongod_hack_rename_arg_save_val --sslClusterPassword --tlsClusterPassword "${mongodHackedArgs[@]}"
	_mongod_hack_rename_arg_save_val --sslCAFile --tlsCAFile "${mongodHackedArgs[@]}"
	_mongod_hack_rename_arg_save_val --sslClusterCAFile --tlsClusterCAFile "${mongodHackedArgs[@]}"
	_mongod_hack_rename_arg_save_val --sslCRLFile --tlsCRLFile "${mongodHackedArgs[@]}"
	_mongod_hack_rename_arg_save_val --sslDisabledProtocols --tlsDisabledProtocols "${mongodHackedArgs[@]}"

	set -- "${mongodHackedArgs[@]}"

	haveBindIp=
	if _mongod_hack_have_arg --bind_ip "$@" || _mongod_hack_have_arg --bind_ip_all "$@"; then
		haveBindIp=1
	elif _parse_config "$@" && jq --exit-status '.net.bindIp // .net.bindIpAll' "$jsonConfigFile" > /dev/null; then
		haveBindIp=1
	fi
	if [ -z "$haveBindIp" ]; then
		set -- "$@" --bind_ip_all
	fi

	unset "${!MONGO_INITDB_@}"
fi

rm -f "$jsonConfigFile" "$tempConfigFile"

if [ "$originalArgOne" = 'mongod' ] || [ "$originalArgOne" = 'mongos' ]; then
	if [ "${PERCONA_TELEMETRY_DISABLE:-1}" != "0" ]; then
		set -- "$@" --setParameter perconaTelemetry=false
	fi
fi

exec "$@"
