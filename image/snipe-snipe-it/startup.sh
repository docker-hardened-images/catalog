#!/bin/bash

file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    local varValue=$(env | grep -E "^${var}=" | sed -E -e "s/^${var}=//")
    local fileVarValue=$(env | grep -E "^${fileVar}=" | sed -E -e "s/^${fileVar}=//")
    if [ -n "${varValue}" ] && [ -n "${fileVarValue}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    if [ -n "${varValue}" ]; then
        export "$var"="${varValue}"
    elif [ -n "${fileVarValue}" ]; then
        export "$var"="$(cat "${fileVarValue}")"
    elif [ -n "${def}" ]; then
        export "$var"="$def"
    fi
    unset "$fileVar"
}

file_env APP_KEY
file_env DB_HOST
file_env DB_PORT
file_env DB_DATABASE
file_env DB_USERNAME
file_env DB_PASSWORD
file_env REDIS_HOST
file_env REDIS_PASSWORD
file_env REDIS_PORT
file_env MAIL_HOST
file_env MAIL_PORT
file_env MAIL_USERNAME
file_env MAIL_PASSWORD

if [ -z "$APP_KEY" -a -z "$APP_KEY_FILE" ]
then
  echo "Please re-run this container with an environment variable \$APP_KEY"
  echo "An example APP_KEY you could use is: "
  /var/www/html/artisan key:generate --show
  exit
fi

mkdir -p /etc/nginx/snipeit
if [ -f /var/lib/snipeit/ssl/snipeit-ssl.crt -a -f /var/lib/snipeit/ssl/snipeit-ssl.key ]
then
  cat > /etc/nginx/snipeit/listen.conf << 'EOF'
listen 80;
listen 443 ssl;
ssl_certificate /var/lib/snipeit/ssl/snipeit-ssl.crt;
ssl_certificate_key /var/lib/snipeit/ssl/snipeit-ssl.key;
EOF
else
  printf '%s\n' 'listen 80;' > /etc/nginx/snipeit/listen.conf
fi

for dir in \
  'data/private_uploads' \
  'data/private_uploads/assets' \
  'data/private_uploads/accessories' \
  'data/private_uploads/audits' \
  'data/private_uploads/components' \
  'data/private_uploads/consumables' \
  'data/private_uploads/eula-pdfs' \
  'data/private_uploads/imports' \
  'data/private_uploads/models' \
  'data/private_uploads/users' \
  'data/private_uploads/licenses' \
  'data/private_uploads/signatures' \
  'data/uploads/accessories' \
  'data/uploads/assets' \
  'data/uploads/avatars' \
  'data/uploads/barcodes' \
  'data/uploads/categories' \
  'data/uploads/companies' \
  'data/uploads/components' \
  'data/uploads/consumables' \
  'data/uploads/departments' \
  'data/uploads/locations' \
  'data/uploads/maintenances' \
  'data/uploads/manufacturers' \
  'data/uploads/models' \
  'data/uploads/suppliers' \
  'dumps' \
  'keys'
do
  [ ! -d "/var/lib/snipeit/$dir" ] && mkdir -p "/var/lib/snipeit/$dir"
done

if [ -v "PHP_UPLOAD_LIMIT" ]
then
    ini=/etc/php-8.3/conf.d/zz-upload-limit.ini
    echo "Changing upload limit to ${PHP_UPLOAD_LIMIT}M in $ini"
    printf 'upload_max_filesize = %sM\npost_max_size = %sM\n' \
      "${PHP_UPLOAD_LIMIT}" "${PHP_UPLOAD_LIMIT}" > "$ini"
    grep -q "^upload_max_filesize = ${PHP_UPLOAD_LIMIT}M$" "$ini"
    grep -q "^post_max_size = ${PHP_UPLOAD_LIMIT}M$" "$ini"
fi

: > /etc/nginx/snipeit/limits.conf
if [ -v "APACHE_LIMIT_REQUEST_FIELD_SIZE" ] || [ -v "APACHE_LIMIT_REQUEST_FIELDS" ]
then
    field_size="${APACHE_LIMIT_REQUEST_FIELD_SIZE:-8k}"
    field_count="${APACHE_LIMIT_REQUEST_FIELDS:-4}"
    echo "Changing large_client_header_buffers to ${field_count} ${field_size}"
    printf 'large_client_header_buffers %s %s;\n' "$field_count" "$field_size" >> /etc/nginx/snipeit/limits.conf
fi
if [ -v "APACHE_LIMIT_REQUEST_LINE" ]
then
    echo "Changing client_header_buffer_size to ${APACHE_LIMIT_REQUEST_LINE}"
    printf 'client_header_buffer_size %s;\n' "${APACHE_LIMIT_REQUEST_LINE}" >> /etc/nginx/snipeit/limits.conf
fi

php /var/www/html/artisan migrate --force
php /var/www/html/artisan config:clear
php /var/www/html/artisan config:cache
php /var/www/html/artisan view:clear
touch /var/www/html/storage/logs/laravel.log

# php-fpm requires an explicit pool user when the master is root. The runtime
# image is already uid 10000, so the pool user is omitted there.
if [ "$(id -u)" -eq 0 ]
then
  # The master is root, so the pool must name its user. The socket is created
  # by that root master; nginx workers run as snipeit and need to connect.
  printf '%s\n' \
    'user = snipeit' \
    'group = snipeit' \
    'listen.owner = snipeit' \
    'listen.group = snipeit' >> /etc/php-8.3/php-fpm.conf
  grep -q '^user = snipeit$' /etc/php-8.3/php-fpm.conf
  grep -q '^group = snipeit$' /etc/php-8.3/php-fpm.conf
  grep -q '^listen.owner = snipeit$' /etc/php-8.3/php-fpm.conf
  grep -q '^listen.group = snipeit$' /etc/php-8.3/php-fpm.conf
fi

/usr/sbin/php-fpm -F -y /etc/php-8.3/php-fpm.conf &
fpm_pid=$!
i=0
while [ ! -S /run/php/php-fpm.sock ]
do
  i=$((i + 1))
  if [ "$i" -gt 50 ]
  then
    echo "php-fpm socket did not appear" >&2
    exit 1
  fi
  if ! kill -0 "$fpm_pid"
  then
    echo "php-fpm exited" >&2
    exit 1
  fi
  sleep 0.1
done

/usr/sbin/nginx -e stderr -g 'daemon off;' &
nginx_pid=$!
sleep 0.5
if ! kill -0 "$nginx_pid"
then
  echo "nginx exited" >&2
  kill "$fpm_pid" 2>/dev/null || true
  exit 1
fi

shutdown() {
  kill "$fpm_pid" "$nginx_pid" 2>/dev/null || true
  wait "$fpm_pid" "$nginx_pid" 2>/dev/null || true
}
trap 'shutdown; exit 0' TERM INT

while true
do
  php /var/www/html/artisan schedule:run
  sleep 1m &
  wait $!
done
