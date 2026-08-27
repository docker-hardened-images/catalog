## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/harbor-exporter:<tag>`
- Mirrored image: `<your-namespace>/dhi-harbor-exporter:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About this harbor-exporter Hardened image

This image contains the Harbor Exporter binary. It is one of several services in a Harbor deployment and is intended to
run alongside `harbor-portal`, `harbor-jobservice`, `harbor-registry`, PostgreSQL, and Redis. The entrypoint for this
image is `/usr/local/bin/harbor-exporter`.

## Start a harbor-exporter image

Harbor Exporter is configured entirely via environment variables. It must be able to reach a running Harbor instance
(PostgreSQL database, Redis, and Harbor core service) to collect metrics.

### Basic usage

```bash
docker run -d --name harbor-exporter -p 9090:9090 \
  -e HARBOR_DATABASE_HOST=harbor-db \
  -e HARBOR_DATABASE_PORT=5432 \
  -e HARBOR_DATABASE_USERNAME=postgres \
  -e HARBOR_DATABASE_PASSWORD=<password> \
  -e HARBOR_DATABASE_DBNAME=registry \
  -e HARBOR_DATABASE_SSLMODE=disable \
  -e HARBOR_REDIS_URL=redis://harbor-redis:6379/1 \
  -e HARBOR_SERVICE_HOST=harbor-core \
  -e HARBOR_SERVICE_PORT=8080 \
  dhi.io/harbor-exporter:<tag>
```

### Entrypoint and ports

- Container listens on `9090/tcp` by default (controlled by `HARBOR_EXPORTER_PORT`).
- Metrics are served at `/metrics` by default (controlled by `HARBOR_EXPORTER_METRICS_PATH`).

## Environment variables and configuration

Harbor Exporter is configured exclusively through environment variables using the `HARBOR_` prefix.

### Exporter settings

| Environment variable                   | Description                            | Default    |
| -------------------------------------- | -------------------------------------- | ---------- |
| `HARBOR_EXPORTER_PORT`                 | Port to listen on for metrics          | `9090`     |
| `HARBOR_EXPORTER_METRICS_PATH`         | HTTP path to expose metrics on         | `/metrics` |
| `HARBOR_EXPORTER_METRICS_ENABLED`      | Enable or disable the metrics endpoint | `true`     |
| `HARBOR_EXPORTER_MAX_REQUESTS`         | Maximum concurrent scrape requests     | `30`       |
| `HARBOR_EXPORTER_CACHE_TIME`           | Seconds to cache metric results        | `23`       |
| `HARBOR_EXPORTER_CACHE_CLEAN_INTERVAL` | Seconds between cache cleanup runs     | `14400`    |

### Harbor connection settings

| Environment variable       | Description                                      |
| -------------------------- | ------------------------------------------------ |
| `HARBOR_SERVICE_HOST`      | Hostname of the Harbor core service              |
| `HARBOR_SERVICE_PORT`      | Port of the Harbor core service                  |
| `HARBOR_SERVICE_SCHEME`    | `http` or `https`                                |
| `HARBOR_DATABASE_HOST`     | PostgreSQL host                                  |
| `HARBOR_DATABASE_PORT`     | PostgreSQL port                                  |
| `HARBOR_DATABASE_USERNAME` | PostgreSQL user                                  |
| `HARBOR_DATABASE_PASSWORD` | PostgreSQL password                              |
| `HARBOR_DATABASE_DBNAME`   | PostgreSQL database name                         |
| `HARBOR_DATABASE_SSLMODE`  | PostgreSQL SSL mode (`disable`, `require`, etc.) |
| `HARBOR_REDIS_URL`         | Redis connection URL                             |
| `HARBOR_REDIS_NAMESPACE`   | Redis key namespace                              |
| `HARBOR_REDIS_TIMEOUT`     | Redis connection timeout                         |

### TLS settings

| Environment variable          | Description                      |
| ----------------------------- | -------------------------------- |
| `HARBOR_EXPORTER_TLS_ENABLED` | Enable TLS on the metrics server |
| `HARBOR_EXPORTER_TLS_CERT`    | Path to the TLS certificate file |
| `HARBOR_EXPORTER_TLS_KEY`     | Path to the TLS key file         |

## Common harbor-exporter use cases

- **Harbor monitoring**: scrape the exporter with Prometheus to track Harbor project quota usage, replication job
  queues, garbage collection status, and overall registry health.

- **Alerting**: use the exposed `harbor_health` and `harbor_up` metrics to alert when Harbor components become
  unavailable.

- **Kubernetes**: deploy as a sidecar or standalone Deployment alongside Harbor, and configure a `ServiceMonitor` for
  Prometheus Operator to automatically discover and scrape the exporter.

## Prometheus scrape configuration

```yaml
scrape_configs:
  - job_name: harbor
    static_configs:
      - targets: ['<exporter-hostname-or-ip>:9090']
```

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
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

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

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
