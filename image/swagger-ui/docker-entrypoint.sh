#!/bin/sh
set -e

INITIALIZER="/usr/share/nginx/html/swagger-initializer.js"

if [ -n "$SWAGGER_JSON_URL" ]; then
  echo "Replacing default Swagger URL with: $SWAGGER_JSON_URL"
  sed -i "s|https://petstore.swagger.io/v2/swagger.json|$SWAGGER_JSON_URL|g" "$INITIALIZER"
fi

if [ -n "$SWAGGER_JSON" ] && [ -f "$SWAGGER_JSON" ]; then
  echo "Serving local Swagger JSON file from: $SWAGGER_JSON"
  cp "$SWAGGER_JSON" /usr/share/nginx/html/swagger.json
  sed -i "s|https://petstore.swagger.io/v2/swagger.json|./swagger.json|g" "$INITIALIZER"
fi

exec "$@"
