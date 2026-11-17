#!/bin/sh
# Upstream command. Applies the OpenSpeedTest environment switches, then execs
# nginx in the foreground so SIGQUIT reaches it. Certificate issuance and cron
# are not started here: certbot and a tail -f PID 1 drop that stop signal.
set -eu

CONFIG=${CONFIG:-/etc/nginx/conf.d/OpenSpeedTest-Server.conf}
INDEX_HTML=${INDEX_HTML:-/usr/share/nginx/html/index.html}

rewrite() {
  expr=$1
  file=$2
  tmp=$(mktemp)
  sed "$expr" "$file" > "$tmp"
  cat "$tmp" > "$file"
  rm -f "$tmp"
}

contains() {
  file=$1
  needle=$2
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *"$needle"*) return 0 ;;
    esac
  done < "$file"
  return 1
}

if [ ! -e /proc/net/if_inet6 ]; then
  rewrite '/listen \[::\]/d' "$CONFIG"
fi

if [ ! -e /proc/net/route ]; then
  rewrite '/listen 300/d' "$CONFIG"
fi

if [ "${CHANGE_CONTAINER_PORTS:-}" = "True" ]; then
  if [ -n "${HTTP_PORT:-}" ]; then
    rewrite "s/3000/${HTTP_PORT}/g" "$CONFIG"
    echo "Changed HTTP container port to ${HTTP_PORT}"
  fi
  if [ -n "${HTTPS_PORT:-}" ]; then
    rewrite "s/3001/${HTTPS_PORT}/g" "$CONFIG"
    echo "Changed HTTPS container port to ${HTTPS_PORT}"
  fi
fi

if [ -n "${VERIFY_OWNERSHIP:-}" ]; then
  verify=/usr/share/nginx/html/Verify.txt
  if [ -f "$verify" ]; then
    echo "Verify.txt Found!"
  else
    printf '%s\n' "$VERIFY_OWNERSHIP" > "$verify"
    echo "Verify.txt Created!"
  fi
fi

if [ -n "${SET_SERVER_NAME:-}" ]; then
  snippet="<h1 style=\"display: inline;color: #7c888d; font-size: 22px;font-family: Roboto-Medium, Roboto;font-weight: 500;\">${SET_SERVER_NAME}</h1>"
  if ! contains "$INDEX_HTML" "$snippet"; then
    tmp=$(mktemp)
    while IFS= read -r line || [ -n "$line" ]; do
      printf '%s\n' "$line"
      case "$line" in
        *"<body>"*) printf '%s\n' "$snippet" ;;
      esac
    done < "$INDEX_HTML" > "$tmp"
    cat "$tmp" > "$INDEX_HTML"
    rm -f "$tmp"
  fi
fi

if [ -n "${ALLOW_ONLY:-}" ]; then
  map=/etc/nginx/conf.d/00-openspeedtest-allow-map.conf
  if [ ! -f "$map" ]; then
    {
      printf '%s\n' 'map $http_origin $allowed_origin {'
      printf '%s\n' '    default 0;'
      oldifs=$IFS
      IFS=';'
      # shellcheck disable=SC2086
      for domain in $ALLOW_ONLY; do
        [ -n "$domain" ] || continue
        escaped=$(printf '%s' "$domain" | sed 's/\./\\./g')
        printf '    "~^https?://(www\\.)?(%s)$" 1;\n' "$escaped"
      done
      IFS=$oldifs
      printf '%s\n' '}'
    } > "$map"
  else
    echo "Map config found! nginx.conf not modified"
  fi

  block='if ($allowed_origin = 0) { return 444; }'
  if ! contains "$CONFIG" 'allowed_origin = 0'; then
    tmp=$(mktemp)
    while IFS= read -r line || [ -n "$line" ]; do
      printf '%s\n' "$line"
      case "$line" in
        *"location / {"*|*"location ~*"*)
          printf '        %s\n' "$block"
          ;;
      esac
    done < "$CONFIG" > "$tmp"
    cat "$tmp" > "$CONFIG"
    rm -f "$tmp"
    echo "Added Block to OpenSpeedTest-Server.conf"
  fi
fi

if [ -n "${DOMAIN_NAME:-}" ]; then
  rewrite "s/YOURDOMAIN/${DOMAIN_NAME}/g" "$CONFIG"
fi

if [ "${ENABLE_LETSENCRYPT:-}" = "True" ] && [ -n "${DOMAIN_NAME:-}" ] && [ -n "${USER_EMAIL:-}" ]; then
  echo "Let's Encrypt issuance is not included. Mount a certificate at /etc/ssl/nginx.crt and /etc/ssl/nginx.key."
fi

exec nginx -g "daemon off;"
