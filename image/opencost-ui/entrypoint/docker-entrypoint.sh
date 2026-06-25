#!/bin/sh
set -e

# Escape replacement text for sed ("&" has special meaning)
escape_sed_replacement() {
    printf '%s' "$1" | sed 's/&/\\&/g'
}

replace_placeholder_in_js() {
    placeholder="$1"
    replacement="$2"

    js_files=$(find "$WWW_ROOT" -type f -name "*.js" 2>/dev/null)
    [ -z "$js_files" ] && return 0

    escaped_replacement=$(escape_sed_replacement "$replacement")
    printf '%s\n' "$js_files" | while IFS= read -r file; do
        sed -i "s^${placeholder}^${escaped_replacement}^g" "$file"
    done
}

# Set document root based on LEGACY_MODE (run with -e LEGACY_MODE=true for legacy UI)
if [ "$LEGACY_MODE" = "true" ] || [ "$LEGACY_MODE" = "1" ] || [ "$LEGACY_MODE" = "yes" ]; then
    export NGINX_ROOT=/var/www/legacy
    WWW_ROOT=/var/www/legacy
    echo "Serving legacy UI from $WWW_ROOT"
else
    export NGINX_ROOT=/var/www
    WWW_ROOT=/var/www
    echo "Serving default UI from $WWW_ROOT"
fi

# Replace placeholders in all .js files (including assets/*.js)
if [ -n "$BASE_URL_OVERRIDE" ]; then
    echo "running with BASE_URL=${BASE_URL_OVERRIDE}"
    replace_placeholder_in_js "{PLACEHOLDER_BASE_URL}" "$BASE_URL_OVERRIDE"
else
    echo "running with BASE_URL=${BASE_URL}"
    replace_placeholder_in_js "{PLACEHOLDER_BASE_URL}" "$BASE_URL"
fi

if [ -n "$OPENCOST_FOOTER_CONTENT" ]; then
    replace_placeholder_in_js "PLACEHOLDER_FOOTER_CONTENT" "$OPENCOST_FOOTER_CONTENT"
else
    replace_placeholder_in_js "PLACEHOLDER_FOOTER_CONTENT" "OpenCost version: $VERSION ($HEAD)"
fi

# Custom aggregation options: JSON object (map string:string), e.g. {"Label: team":"label:team"}
if [ -n "$CUSTOM_AGGREGATION_OPTIONS" ]; then
    echo "injecting CUSTOM_AGGREGATION_OPTIONS"
    esc=$(printf '%s' "$CUSTOM_AGGREGATION_OPTIONS" | sed 's/\\/\\\\/g; s/"/\\"/g')
    replace_placeholder_in_js "PLACEHOLDER_CUSTOM_AGGREGATIONS" "$esc"
fi

# Drop the welcome server the nginx package ships at conf.d/default.conf so it is
# not served alongside opencost's server (conf.d is owned by the nginx user, so
# this root-owned file can be unlinked).
rm -f /etc/nginx/conf.d/default.conf

# Generate opencost's server block from the template, but only if conf.d does not
# already provide default.nginx.conf. The upstream OpenCost helm chart mounts its
# own default.nginx.conf here; honor it (do not clobber) when present.
if [ ! -e /etc/nginx/conf.d/default.nginx.conf ]; then
    envsubst '$API_PORT $API_SERVER $UI_PORT $NGINX_ROOT $UI_PATH $BASE_URL $PROXY_CONNECT_TIMEOUT $PROXY_SEND_TIMEOUT $PROXY_READ_TIMEOUT' \
        < /etc/nginx/default.nginx.conf.template \
        > /etc/nginx/conf.d/default.nginx.conf
fi
echo "Starting OpenCost UI version $VERSION ($HEAD)"

exec "$@"
