## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kong:<tag>`
- Mirrored image: `<your-namespace>/dhi-kong:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Refer to the [upstream's documentation](https://docs.konghq.com/) on the subject of configuring Kong for your needs.

### What's included in this Kong Hardened image

This Docker Hardened Kong image includes:

- **kong**: Main Kong Gateway binary for routing, authentication, rate limiting, and traffic control
- **kong-health**: Health check utility for container health monitoring
- **OpenResty**: NGINX + LuaJIT runtime environment that powers Kong's plugin architecture
- **LuaRocks**: Lua package manager (luarocks and luarocks-admin) for installing custom plugins in dev variants

## Start a Kong image

Run a basic Kong container and output the version with the following command. Replace <tag> with the image variant you
want to run.

```bash
docker run dhi.io/kong:<tag> kong version
```

Run Kong in DB-less mode with a declarative configuration:

```bash
docker run -v /path/to/kong.yaml:/etc/kong/kong.yaml:ro \
  -e "KONG_DATABASE=off" \
  -e "KONG_DECLARATIVE_CONFIG=/etc/kong/kong.yaml" \
  -p 8000:8000 -p 8001:8001 \
  dhi.io/kong:<tag>
```

## Common Kong use cases

#### Basic API gateway with DB-less mode

Create a declarative configuration in `kong.yaml`:

```yaml
_format_version: "3.0"

services:
  - name: example-service
    url: http://httpbin.org
    routes:
      - name: example-route
        paths:
          - /example
```

Run Kong with this configuration:

```bash
docker run -v $(pwd)/kong.yaml:/etc/kong/kong.yaml:ro \
  -e "KONG_DATABASE=off" \
  -e "KONG_DECLARATIVE_CONFIG=/etc/kong/kong.yaml" \
  -p 8000:8000 -p 8001:8001 \
  dhi.io/kong:<tag>
```

#### API gateway with authentication plugin

Add authentication to your services in `kong.yaml`:

```yaml
_format_version: "3.0"

services:
  - name: protected-api
    url: http://api.example.com
    routes:
      - name: api-route
        paths:
          - /api
    plugins:
      - name: key-auth
        config:
          key_names:
            - apikey

consumers:
  - username: demo-user
    keyauth_credentials:
      - key: my-secret-key
```

Test the protected endpoint:

```bash
# Without authentication - returns 401
curl http://localhost:8000/api

# With authentication - proxies to upstream
curl -H "apikey: my-secret-key" http://localhost:8000/api
```

#### Rate limiting configuration

Configure rate limiting in `kong.yaml`:

```yaml
_format_version: "3.0"

services:
  - name: rate-limited-service
    url: http://httpbin.org
    routes:
      - name: limited-route
        paths:
          - /limited
    plugins:
      - name: rate-limiting
        config:
          minute: 10
          policy: local
```

#### Kong with PostgreSQL database

Using Docker Compose for Kong with database:

```yaml
services:
  postgres:
    image: dhi.io/postgres:16
    environment:
      POSTGRES_USER: kong
      POSTGRES_DB: kong
      POSTGRES_PASSWORD: kong
    volumes:
      - kong-db:/var/lib/postgresql/data

  kong-migrations:
    image: dhi.io/kong:<tag>-dev
    command: kong migrations bootstrap
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: postgres
      KONG_PG_USER: kong
      KONG_PG_PASSWORD: kong
    depends_on:
      - postgres

  kong:
    image: dhi.io/kong:<tag>
    environment:
      KONG_DATABASE: postgres
      KONG_PG_HOST: postgres
      KONG_PG_USER: kong
      KONG_PG_PASSWORD: kong
      KONG_PROXY_LISTEN: 0.0.0.0:8000
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
    ports:
      - "8000:8000"
      - "8001:8001"
    depends_on:
      - kong-migrations

volumes:
  kong-db:
```

## Docker Official Images vs. Docker Hardened Images

Key differences for Kong:

| Feature         | Docker Official Kong           | Docker Hardened Kong                                |
| --------------- | ------------------------------ | --------------------------------------------------- |
| Security        | Standard base with utilities   | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available | No shell in runtime variants                        |
| Package manager | apt available                  | No package manager in runtime variants              |
| Attack surface  | Larger due to extra utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging    | Use Docker Debug or Image Mount for troubleshooting |

## Image variants

Docker Hardened Images come in different variants depending on their intended use:

- **Runtime variants** are designed to run Kong in production. These images:

  - Run as the nonroot user
  - Do not include a shell or package manager
  - Contain only the minimal set of libraries needed to run Kong

- **Build-time variants** typically include `dev` in the variant name and are intended for database migrations or
  building custom Kong plugins. These images:

  - Run as the root user
  - Include a shell and package manager
  - Can be used to run `kong migrations` commands or compile custom plugins

- **FIPS variants** include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

### Kong-specific migration requirements

When migrating from Docker Official Images to Docker Hardened Images for Kong, consider the following:

#### Port binding restrictions

The nonroot user cannot bind to privileged ports (below 1024). Update your Kong configuration to use ports 1025 and
above inside the container:

```bash
# Set environment variables for unprivileged ports
docker run \
  -e "KONG_PROXY_LISTEN=0.0.0.0:8000" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
  -p 80:8000 -p 8001:8001 \
  dhi.io/kong:<tag>
```

Use Docker's port mapping to expose these on privileged ports on the host:

```bash
docker run -p 80:8000 -p 443:8443 dhi.io/kong:<tag>
```

#### Configuration file permissions

Ensure configuration files are readable by the nonroot user. Mount configurations with appropriate permissions:

```bash
chmod 644 kong.yaml
docker run -v $(pwd)/kong.yaml:/etc/kong/kong.yaml:ro \
  dhi.io/kong:<tag>
```

#### Database migrations

When using Kong with a database, run migrations using the dev variant before starting the runtime container:

```bash
# Run migrations with dev variant
docker run --rm \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=postgres" \
  dhi.io/kong:<tag>-dev kong migrations bootstrap

# Then start Kong with runtime variant
docker run \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=postgres" \
  dhi.io/kong:<tag>
```

#### Custom plugins

If using custom plugins, compile them using the dev variant and copy to a mounted volume accessible by the runtime
container:

```bash
# Build custom plugin with dev variant
docker run -v $(pwd)/plugins:/plugins dhi.io/kong:<tag>-dev \
  bash -c "cd /plugins && luarocks make"

# Run Kong with custom plugins
docker run -v $(pwd)/plugins:/usr/local/lib/lua/5.1/kong/plugins \
  -e "KONG_PLUGINS=bundled,my-custom-plugin" \
  dhi.io/kong:<tag>
```

#### Entry point differences

Verify the entry point behavior matches your expectations. Use `docker inspect` to check:

```bash
docker inspect dhi.io/kong:<tag>
```

## Troubleshooting migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use Docker Debug to attach to these containers. Docker
Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that
only exists during the debugging session.

```bash
docker debug dhi.io/kong:<tag>
```

### Kong won't start - permission denied on port binding

Symptom: Kong fails to start with a "permission denied" error when binding to ports below 1024.

Solution: Update your environment variables to use unprivileged ports (1025 and above) and use Docker port mapping to
expose privileged ports on the host:

```bash
docker run \
  -e "KONG_PROXY_LISTEN=0.0.0.0:8000" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001" \
  -p 80:8000 -p 8001:8001 \
  dhi.io/kong:<tag>
```

### Configuration file not found or not readable

Symptom: Kong reports that it cannot read the declarative configuration file.

Solution: Verify that:

- The configuration file exists in the mounted location
- The file has appropriate read permissions (644 or similar)
- The mount path in the Docker command matches the path specified in `KONG_DECLARATIVE_CONFIG`
- The YAML syntax is valid (use `kong config parse` with dev variant to validate)

### Database migration errors

Symptom: Kong fails to start with database connection or schema errors.

Solution: Ensure migrations are run using the dev variant before starting Kong:

```bash
docker run --rm \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=postgres" \
  -e "KONG_PG_USER=kong" \
  -e "KONG_PG_PASSWORD=kong" \
  dhi.io/kong:<tag>-dev kong migrations bootstrap
```

For upgrades, run:

```bash
docker run --rm \
  -e "KONG_DATABASE=postgres" \
  -e "KONG_PG_HOST=postgres" \
  dhi.io/kong:<tag>-dev kong migrations up
```

### Custom plugins not loading

Symptom: Kong reports that custom plugins cannot be found or loaded.

Solution: Ensure custom plugins are:

- Compiled with the dev variant matching your Kong version
- Mounted to the correct path (`/usr/local/lib/lua/5.1/kong/plugins`)
- Listed in the `KONG_PLUGINS` environment variable
- Have proper file permissions (644 for files, 755 for directories)

### Cannot debug running container

Symptom: Unable to exec into the container because there's no shell.

Solution: Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach an ephemeral debugging
session to the container with a shell and debugging tools.

## Other

### Configuration validation

To validate your Kong declarative configuration before deploying, use a dev variant image:

```bash
docker run --rm -v $(pwd)/kong.yaml:/tmp/kong.yaml:ro \
  dhi.io/kong:<tag>-dev \
  kong config parse /tmp/kong.yaml
```

### Health checks

The Kong image includes a `kong-health` utility for health checking:

```bash
docker run dhi.io/kong:<tag> kong-health
```

In Docker Compose, configure health checks:

```yaml
services:
  kong:
    image: dhi.io/kong:<tag>
    healthcheck:
      test: ["CMD", "kong-health"]
      interval: 10s
      timeout: 5s
      retries: 5
```

### Additional documentation

For detailed Kong configuration, plugin documentation, and API reference, refer to the
[official Kong documentation](https://docs.konghq.com/).
