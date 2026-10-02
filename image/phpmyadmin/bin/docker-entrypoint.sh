#!/bin/sh
set -eu

tighten_config() {
    chmod 0640 "$1"
    chgrp nonroot "$1" 2>/dev/null || true
}

if [ "${1:-}" = "php-fpm" ]; then
    if [ -n "${PMA_CONFIG_BASE64:-}" ]; then
        echo "Adding the custom config.inc.php from base64."
        rm -f /etc/phpmyadmin/config.inc.php
        (umask 077; echo "${PMA_CONFIG_BASE64}" | base64 -d > /etc/phpmyadmin/config.inc.php)
        tighten_config /etc/phpmyadmin/config.inc.php
    elif [ ! -f /etc/phpmyadmin/config.secret.inc.php ]; then
        secret=$(tr -dc 'a-zA-Z0-9~!@#$%^&*_()+}{?></";.,[]=-' < /dev/urandom | fold -w 32 | head -n 1)
        (umask 077; printf '<?php\n$cfg['\''blowfish_secret'\''] = '\''%s'\'';\n' "$secret" > /etc/phpmyadmin/config.secret.inc.php)
        tighten_config /etc/phpmyadmin/config.secret.inc.php
    fi

    if [ -n "${PMA_USER_CONFIG_BASE64:-}" ]; then
        echo "Adding the custom config.user.inc.php from base64."
        rm -f /etc/phpmyadmin/config.user.inc.php
        (umask 077; echo "${PMA_USER_CONFIG_BASE64}" | base64 -d > /etc/phpmyadmin/config.user.inc.php)
        tighten_config /etc/phpmyadmin/config.user.inc.php
    elif [ ! -f /etc/phpmyadmin/config.user.inc.php ] && [ -w /etc/phpmyadmin ]; then
        touch /etc/phpmyadmin/config.user.inc.php
    fi
fi

read_secret_file() {
    var="$1"
    file=$(eval "printf '%s' \"\${${var}_FILE:-}\"")
    if [ -n "$file" ]; then
        if [ ! -r "$file" ]; then
            echo "docker-entrypoint.sh: cannot read ${var}_FILE: $file" >&2
            exit 1
        fi
        val=$(cat "$file")
        export "$var"="$val"
    fi
}

read_secret_file PMA_USER
read_secret_file PMA_PASSWORD
read_secret_file MYSQL_ROOT_PASSWORD
read_secret_file MYSQL_PASSWORD
read_secret_file PMA_HOSTS
read_secret_file PMA_HOST
read_secret_file PMA_CONTROLHOST
read_secret_file PMA_CONTROLUSER
read_secret_file PMA_CONTROLPASS

exec "$@"
