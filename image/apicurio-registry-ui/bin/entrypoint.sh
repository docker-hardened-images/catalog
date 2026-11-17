#!/bin/sh

set -e

: "${REGISTRY_CONFIG_OUTPUT_PATH:=/var/lib/apicurio-registry-ui/config.js}"
: "${REGISTRY_INDEXHTML_PATH:=/var/lib/apicurio-registry-ui/index.html}"
export REGISTRY_CONFIG_OUTPUT_PATH REGISTRY_INDEXHTML_PATH

TLS_CERT=/etc/pki/nginx/server.crt
TLS_KEY=/etc/pki/nginx/private/server.key

# update-base-href.cjs rewrites the file in place, so start from the packaged
# copy every time to keep restarts idempotent.
cp /usr/share/apicurio-registry-ui/index.html "$REGISTRY_INDEXHTML_PATH"

if [ ! -f "$TLS_CERT" ] || [ ! -f "$TLS_KEY" ]; then
    echo "Generating a self-signed certificate for the TLS listener on port 1337..."
    if ! out=$(openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 3650 \
        -subj "/CN=localhost" \
        -keyout "$TLS_KEY" -out "$TLS_CERT" 2>&1); then
        echo "$out" >&2
        echo "error: could not write $TLS_CERT and $TLS_KEY" >&2
        exit 1
    fi
fi

echo "---------------------------------------------"
echo "Performing the Initial Config..."
echo "---------------------------------------------"
node /usr/lib/apicurio-registry-ui/create-config.cjs

echo "---------------------------------------------"
echo "Patching base hrefs..."
echo "---------------------------------------------"
node /usr/lib/apicurio-registry-ui/update-base-href.cjs

# Both scripts log and exit 0 when they cannot write their output.
for f in "$REGISTRY_CONFIG_OUTPUT_PATH" "$REGISTRY_INDEXHTML_PATH"; do
    if [ ! -s "$f" ]; then
        echo "error: $f was not generated" >&2
        exit 1
    fi
done

echo "---------------------------------------------"
echo "Config Complete. Nginx Server Started....."
echo "---------------------------------------------"

if [ "$#" -eq 0 ]; then
    set -- nginx -g 'daemon off;'
fi

exec "$@"
