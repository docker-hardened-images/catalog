# Swagger UI Deployment Guide

`swagger-ui` is hosted on a secure, minimal non-root Nginx base listening on port `8080` (running as user `nginx` with UID 65532).

## Run with a Remote OpenAPI Spec

Configure the container to point to a remote URL containing the OpenAPI JSON or YAML spec:

```bash
docker run -d --name swagger-ui \
  -p 8080:8080 \
  -e SWAGGER_JSON_URL=https://petstore.swagger.io/v2/swagger.json \
  dhi.io/swagger-ui:5.32.6
```

## Run with a Mounted Local Spec

If you want to render a local specification file:

```bash
docker run -d --name swagger-ui \
  -p 8080:8080 \
  -v $(pwd)/openapi.yaml:/usr/share/nginx/html/openapi.yaml \
  -e SWAGGER_JSON=/usr/share/nginx/html/openapi.yaml \
  dhi.io/swagger-ui:5.32.6
```

## Security Best Practices

Our Swagger UI image is strictly hardened:
- **No Node.js in Runtime**: The development-time Node tools are stripped. Only Nginx and static JS/HTML remain, minimizing the threat vectors.
- **Runs Non-Root**: The web server runs natively as UID/GID `65532:65532`.
- **Read-Only Root Filesystem Compatible**: The dynamic substitution takes place inside a writable `/tmp` buffer directory if needed, allowing the root filesystem to be run with the `--read-only` flag safely (with standard Nginx temp paths configured as tmpfs mounts).
