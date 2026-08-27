## How to use this image

All examples in this guide use a mirrored DHI image namespace. Replace <your-namespace> with your registry or namespace
and <tag> with the image tag you use.

- Mirrored image: `<your-namespace>/dhi-envoy-ratelimit:<tag>`

### What's included in this envoy-ratelimit image

This Docker Hardened envoy-ratelimit image includes:

- The ratelimit binary: /usr/bin/ratelimit (gRPC and HTTP/JSON server)

## Start an envoy-ratelimit image

This section shows common ways to run the service. Envoy Rate Limit exposes an HTTP JSON endpoint (commonly on port
8080\) for testing and a gRPC server (commonly on port 6070) that Envoy uses.

### Basic usage

```bash
# Run with a Redis backend (recommended for production)
$ docker run -d --name ratelimit \
  -p 8080:8080 -p 6070:6070 \
  -e BACKEND_TYPE=redis \
  -e REDIS_SOCKET_TYPE=tcp \
  -e REDIS_URL=redis:6379 \
  -e RUNTIME_ROOT=/home/nonroot \
  -e RUNTIME_SUBDIRECTORY=ratelimit \
  -e CONFIG_TYPE=FILE \
  -e FORCE_START_WITHOUT_INITIAL_CONFIG=true \
  <your-namespace>/dhi-envoy-ratelimit:<tag> /bin/ratelimit
```

> Note: The hardened image runs as a nonroot user and is based on a distroless runtime. Mount configuration and data
> directories with correct permissions for the nonroot user.

### Docker Compose (example)

```yaml
version: '3.8'
services:
  redis:
    image: redis:alpine
    container_name: ratelimit-redis
    ports:
      - "6379:6379"

  ratelimit:
    image: <your-namespace>/dhi-envoy-ratelimit:<tag>
    command: ["/bin/ratelimit"]
    container_name: ratelimit
    depends_on:
      - redis
    ports:
      - "8080:8080"
      - "6070:6070"
    environment:
      BACKEND_TYPE: redis
      REDIS_SOCKET_TYPE: tcp
      REDIS_URL: redis:6379
      RUNTIME_ROOT: /home/nonroot
      RUNTIME_SUBDIRECTORY: ratelimit
      CONFIG_TYPE: FILE
      FORCE_START_WITHOUT_INITIAL_CONFIG: "true"
    volumes:
      - ./config:/home/nonroot/ratelimit/config:ro
```

### Environment variables

Key environment variables supported by the ratelimit service (sourced from upstream README and tests):

| Variable                           | Description                                                             | Default       | Required                             |
| ---------------------------------- | ----------------------------------------------------------------------- | ------------- | ------------------------------------ |
| BACKEND_TYPE                       | Backend type for counters (redis or memcache)                           | redis         | No (recommended: redis)              |
| REDIS_SOCKET_TYPE                  | Socket type for Redis (tcp or unix)                                     | tcp           | If using redis backend               |
| REDIS_URL                          | Redis connection string (host:port)                                     | -             | If using redis backend               |
| RUNTIME_ROOT                       | Runtime directory root where configuration and runtime files are stored | /home/nonroot | Yes (when using FILE config)         |
| RUNTIME_SUBDIRECTORY               | Subdirectory under RUNTIME_ROOT for this app (common: ratelimit)        | ratelimit     | Yes (when using FILE config)         |
| CONFIG_TYPE                        | CONFIG_TYPE=FILE or CONFIG_TYPE=GRPC (xDS)                              | FILE          | Yes                                  |
| CONFIG_GRPC_XDS_SERVER_URL         | If using xDS, address of xDS management server                          | -             | If using GRPC xDS                    |
| FORCE_START_WITHOUT_INITIAL_CONFIG | If true, start even without initial config                              | false         | No (test uses true to avoid waiting) |
| USE_STATSD                         | Enable statsd metrics emission                                          | false         | No                                   |
| STATSD_HOST                        | StatsD host for metrics                                                 | -             | If USE_STATSD=true                   |
| STATSD_PORT                        | StatsD port for metrics                                                 | 9125          | If USE_STATSD=true                   |
| LOG_LEVEL                          | Log level (debug, info, warn, error)                                    | info          | No                                   |

Example: mounting a local config file into the runtime directory

```bash
# From project root where config/config.yaml exists
$ docker run --rm -v $(pwd)/config:/home/nonroot/ratelimit/config:ro \
  -e CONFIG_TYPE=FILE -e RUNTIME_ROOT=/home/nonroot -e RUNTIME_SUBDIRECTORY=ratelimit \
  <your-namespace>/dhi-envoy-ratelimit:<tag> /bin/ratelimit
```

## Common envoy-ratelimit use cases

- Basic file-backed rate limiting for Envoy: mount a `config.yaml` into `/home/nonroot/ratelimit/config` and run with
  CONFIG_TYPE=FILE. Configure Envoy to call the gRPC rate limit service at the container's 6070 port.

- Integration testing: use the HTTP `/json` endpoint (port 8080) to submit descriptor requests for quick verification of
  behavior without an Envoy instance.

- Production with Redis: point REDIS_URL to a managed Redis cluster, run multiple rate limit instances, and use Envoy's
  cluster configuration to load-balance gRPC requests to the service instances.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants. *End of FIPS section*

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

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

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
