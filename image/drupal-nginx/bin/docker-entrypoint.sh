#!/usr/bin/env bash

# Renders the wodby/nginx gotpl configuration set into /etc/nginx and then execs
# the command. Two deliberate differences from upstream wodby/nginx:
#
#   * upstream runs `sudo init_volumes` to chown the application and files
#     directories, then `sudo nginx`. The hardened image has no sudo and never
#     runs as root, so the directories are created with the right ownership at
#     build time and nginx is exec'd directly.
#   * exec_init_scripts is inlined as a call to the bundled init script; the
#     hardened image does not ship the wodby base image helper library.

set -e

if [[ -n "${DEBUG}" ]]; then
    set -x
fi

_gotpl() {
    if [[ -f "/etc/gotpl/$1" ]]; then
        gotpl "/etc/gotpl/$1" > "$2"
    fi
}

# Backwards compatibility for old env vars names.
_backwards_compatibility() {
    declare -A vars
    # vars[DEPRECATED]="ACTUAL"
    vars[NGINX_ALLOW_XML_ENDPOINTS]="NGINX_DRUPAL_ALLOW_XML_ENDPOINTS"
    vars[NGINX_STATIC_CONTENT_ACCESS_LOG]="NGINX_STATIC_ACCESS_LOG"
    vars[NGINX_STATIC_CONTENT_EXPIRES]="NGINX_STATIC_EXPIRES"
    vars[NGINX_STATIC_CONTENT_OPEN_FILE_CACHE]="NGINX_STATIC_OPEN_FILE_CACHE"
    vars[NGINX_STATIC_CONTENT_OPEN_FILE_CACHE_MIN_USES]="NGINX_STATIC_OPEN_FILE_CACHE_MIN_USES"
    vars[NGINX_STATIC_CONTENT_OPEN_FILE_CACHE_VALID]="NGINX_STATIC_OPEN_FILE_CACHE_VALID"
    vars[NGINX_XMLRPC_SERVER_NAME]="NGINX_DRUPAL_XMLRPC_SERVER_NAME"
    vars[NGINX_DRUPAL_TRACK_UPLOADS]="NGINX_TRACK_UPLOADS"

    for i in "${!vars[@]}"; do
        # Use value from old var if it's not empty and the new is.
        if [[ -n "${!i}" && -z "${!vars[$i]}" ]]; then
            export ${vars[$i]}="${!i}"
        fi
    done
}

process_templates() {
    _backwards_compatibility

    # Override default CSP header for Drupal and WP.
    if [[ "${NGINX_VHOST_PRESET}" = drupal* || ${NGINX_VHOST_PRESET} = wordpress ]]; then
      if [[ -z "${NGINX_HEADERS_CONTENT_SECURITY_POLICY}" ]]; then
        export NGINX_HEADERS_CONTENT_SECURITY_POLICY="frame-ancestors 'self'"
      fi
    fi

    _gotpl "config/nginx.conf.tmpl" "/etc/nginx/nginx.conf"
    _gotpl "vhost.conf.tmpl" "/etc/nginx/conf.d/vhost.conf"
    _gotpl "includes/defaults.conf.tmpl" "/etc/nginx/defaults.conf"
    _gotpl "includes/fastcgi.conf.tmpl" "/etc/nginx/fastcgi.conf"

    if [[ -n "${NGINX_VHOST_PRESET}" ]]; then
        _gotpl "presets/${NGINX_VHOST_PRESET}.conf.tmpl" "/etc/nginx/preset.conf"

        if [[ "${NGINX_VHOST_PRESET}" = drupal* || "${NGINX_VHOST_PRESET}" =~ ^wordpress|matomo|php|laravel$ ]]; then
            _gotpl "includes/upstream.php.conf.tmpl" "/etc/nginx/upstream.conf"
        elif [[ "${NGINX_VHOST_PRESET}" =~ ^http-proxy|django$ ]]; then
            if [[ -z "${NGINX_BACKEND_HOST}" && "${NGINX_VHOST_PRESET}" == "django" ]]; then
                export NGINX_BACKEND_HOST="python";
            fi

            _gotpl "includes/upstream.http-proxy.conf.tmpl" "/etc/nginx/upstream.conf"
        elif [[ -f "/etc/gotpl/includes/upstream.${NGINX_VHOST_PRESET}.conf.tmpl" ]]; then
            _gotpl "includes/upstream.${NGINX_VHOST_PRESET}.conf.tmpl" "/etc/nginx/upstream.conf"
        else
            touch /etc/nginx/upstream.conf
        fi
    fi

    _gotpl "50x.html.tmpl" "/usr/share/nginx/html/50x.html"
}

process_templates

# Preset specific directory and symlink setup (Drupal sites/<site>/files, and
# the WordPress and Laravel equivalents).
init

exec "$@"
