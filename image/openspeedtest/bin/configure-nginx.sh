#!/bin/sh
set -eu

if grep -q '/etc/nginx/http\.d/' /etc/nginx/nginx.conf; then
  sed -i '/^include \/etc\/nginx\/conf\.d\/\*\.conf;/d' /etc/nginx/nginx.conf
  sed -i 's,/etc/nginx/http\.d/,/etc/nginx/conf.d/,' /etc/nginx/nginx.conf
  sed -i '/^user nginx;/d' /etc/nginx/nginx.conf
fi

sed -i '/ssl_session_cache/d' /etc/nginx/nginx.conf
sed -i 's/worker_connections[[:space:]]*1024;/worker_connections 2048;/' /etc/nginx/nginx.conf

if ! grep -q multi_accept /etc/nginx/nginx.conf; then
  tmp=$(mktemp)
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "$line"
    case "$line" in
      *worker_connections*)
        printf '%s\n' '    multi_accept on;'
        ;;
    esac
  done < /etc/nginx/nginx.conf > "$tmp"
  cat "$tmp" > /etc/nginx/nginx.conf
  rm -f "$tmp"
fi

mkdir -p /etc/nginx/conf.d /run/nginx /var/log/nginx /etc/ssl
# nginx-stable ships conf.d/default.conf: a server on port 8080 rooted at the document root.
if [ -f /etc/nginx/conf.d/default.conf ]; then
  : > /etc/nginx/conf.d/default.conf
fi
if [ -f /etc/nginx/http.d/default.conf ]; then
  : > /etc/nginx/http.d/default.conf
fi
rm -f /etc/nginx/sites-enabled/default

cp /usr/share/openspeedtest/nginx/openspeedtest.conf /etc/nginx/conf.d/OpenSpeedTest-Server.conf
chown 65532:65532 /etc/nginx/conf.d /etc/nginx/conf.d/OpenSpeedTest-Server.conf
chmod 0775 /etc/nginx/conf.d
chmod 0664 /etc/nginx/conf.d/OpenSpeedTest-Server.conf
chown root:root /etc/nginx/nginx.conf
chmod 0644 /etc/nginx/nginx.conf

chown -R 65532:65532 /usr/share/openspeedtest
mkdir -p /tmp
chmod 1777 /tmp

for dir in /var/log/letsencrypt /etc/letsencrypt /var/lib/letsencrypt; do
  mkdir -p "$dir"
  chown 65532:65532 "$dir"
  chmod 0755 "$dir"
done

OPENSSL_CONF=/dev/null openssl req -x509 -nodes -newkey rsa:2048 \
  -keyout /etc/ssl/nginx.key \
  -out /etc/ssl/nginx.crt \
  -days 3650 \
  -subj /CN=localhost
chmod 0444 /etc/ssl/nginx.crt /etc/ssl/nginx.key

for dir in /run/nginx /var/log/nginx /var/cache/nginx /var/lib/nginx; do
  if [ -d "$dir" ]; then
    chown -R 65532:65532 "$dir"
  fi
done

ln -sf /dev/stdout /var/log/nginx/access.log
ln -sf /dev/stderr /var/log/nginx/error.log
