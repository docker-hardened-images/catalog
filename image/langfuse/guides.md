## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Langfuse image

Langfuse is a multi-service application. A working deployment requires at least a PostgreSQL database, and — from v3
onward — a ClickHouse instance and a Redis cache. The container reads its configuration from environment variables and
serves the web UI on port `3000`.

### Basic usage

For Langfuse 2.x, provide PostgreSQL and the shared application secrets:

```bash
$ docker run -d --name langfuse -p 3000:3000 \
  -e DATABASE_URL=postgresql://USER:PASSWORD@HOST:5432/langfuse \
  -e NEXTAUTH_URL=http://localhost:3000 \
  -e NEXTAUTH_SECRET=$(openssl rand -base64 32) \
  -e SALT=$(openssl rand -base64 32) \
  -e ENCRYPTION_KEY=$(openssl rand -hex 32) \
  dhi.io/langfuse:2
```

For Langfuse 3.x, provide the same shared settings plus ClickHouse, Redis, and object storage configuration:

```bash
$ docker run -d --name langfuse -p 3000:3000 \
  -e DATABASE_URL=postgresql://USER:PASSWORD@POSTGRES_HOST:5432/langfuse \
  -e NEXTAUTH_URL=http://localhost:3000 \
  -e NEXTAUTH_SECRET=$(openssl rand -base64 32) \
  -e SALT=$(openssl rand -base64 32) \
  -e ENCRYPTION_KEY=$(openssl rand -hex 32) \
  -e CLICKHOUSE_URL=http://CLICKHOUSE_HOST:8123 \
  -e CLICKHOUSE_MIGRATION_URL=clickhouse://CLICKHOUSE_HOST:9000 \
  -e CLICKHOUSE_USER=default \
  -e CLICKHOUSE_PASSWORD=PASSWORD \
  -e CLICKHOUSE_CLUSTER_ENABLED=false \
  -e REDIS_HOST=REDIS_HOST \
  -e LANGFUSE_S3_EVENT_UPLOAD_BUCKET=langfuse-events \
  dhi.io/langfuse:3
```

### Environment variables

Only the most common variables are listed below. The full configuration reference is maintained upstream at
<https://langfuse.com/self-hosting/configuration>.

| Variable                          | Description                                                     | Required       |
| --------------------------------- | --------------------------------------------------------------- | -------------- |
| `DATABASE_URL`                    | PostgreSQL connection URL. Credentials must be percent-encoded. | Yes            |
| `NEXTAUTH_URL`                    | Public URL of the Langfuse instance.                            | Yes            |
| `NEXTAUTH_SECRET`                 | Random secret used to sign session tokens.                      | Yes            |
| `SALT`                            | Random secret used for one-way hashing.                         | Yes            |
| `ENCRYPTION_KEY`                  | 256-bit hex key for symmetric encryption of stored secrets.     | Yes            |
| `CLICKHOUSE_URL`                  | ClickHouse HTTP URL.                                            | Yes from v3    |
| `CLICKHOUSE_MIGRATION_URL`        | ClickHouse native connection URL for migrations.                | Yes from v3    |
| `CLICKHOUSE_USER`                 | ClickHouse username.                                            | Yes from v3    |
| `CLICKHOUSE_PASSWORD`             | ClickHouse password.                                            | Yes from v3    |
| `CLICKHOUSE_CLUSTER_ENABLED`      | Set to `false` for single-node ClickHouse migrations.           | v3 single-node |
| `REDIS_HOST`                      | Redis hostname for the job queue.                               | Yes from v3    |
| `LANGFUSE_S3_EVENT_UPLOAD_BUCKET` | Object storage bucket for event uploads.                        | Yes from v3    |

## Common Langfuse use cases

- **Self-hosted LLM observability platform** — collect traces, evaluations and prompts from your AI applications behind
  your own infrastructure.
- **Drop-in replacement** for `docker.io/langfuse/langfuse` in existing Compose stacks and Helm charts. The entry point
  (`dumb-init -- ./web/entrypoint.sh`) and default port (`3000`) match upstream.

For reference Docker Compose stacks, Helm charts and supported topologies (single-node, distributed, clustered), see the
upstream self-hosting docs: <https://langfuse.com/self-hosting>.

## Non-hardened images vs. Docker Hardened Images

The Docker Hardened Langfuse image is functionally equivalent to the upstream `docker.io/langfuse/langfuse` image for
self-hosted deployments and accepts the same configuration. The notable runtime differences are:

- The runtime image contains only the minimal shell needed by the entrypoint, no package manager, and no general-purpose
  utilities (`sed`, `coreutils`, `findutils`, …). Custom `docker exec` workflows that rely on those binaries must be
  updated — use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) or the `dev` variant instead.
- The bundled `prisma` CLI is invoked through an absolute Node interpreter path; users overriding the entrypoint should
  call it as `prisma` (already on `PATH`) rather than reaching into `/opt/prisma/lib/`.

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
