## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a langfuse-worker instance

Langfuse Worker is a backend-only service that requires several external services before it will start. At minimum it
needs a running PostgreSQL database and a Redis instance; v3 additionally requires a ClickHouse instance and an
accessible object storage bucket. Providing only the image without these dependencies causes the process to exit
immediately. Set the required environment variables described in the next section, then confirm the worker is healthy by
querying its health endpoint:

```bash
$ curl http://localhost:3030/api/health
{"status":"ok"}
```

The readiness endpoint is available at `GET /api/ready` on the same port.

## Common langfuse-worker use cases

### Full Langfuse stack with Docker Compose

The most common deployment runs the worker alongside the Langfuse web service and all required infrastructure in a
single Compose file. The worker and the web service share the same database credentials and application secrets.

```yaml
services:
  postgres:
    image: postgres:16
    environment:
      POSTGRES_USER: langfuse
      POSTGRES_PASSWORD: langfuse
      POSTGRES_DB: langfuse
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U langfuse"]
      interval: 10s
      timeout: 5s
      retries: 5

  clickhouse:
    image: clickhouse/clickhouse-server:24
    environment:
      CLICKHOUSE_DB: default
      CLICKHOUSE_USER: default
      CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT: "1"
      CLICKHOUSE_PASSWORD: clickhouse
    volumes:
      - clickhouse-data:/var/lib/clickhouse
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:8123/ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  minio:
    image: minio/minio
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin
    volumes:
      - minio-data:/data
    healthcheck:
      test: ["CMD", "mc", "ready", "local"]
      interval: 10s
      timeout: 5s
      retries: 5

  langfuse:
    image: dhi.io/langfuse:<tag>
    ports:
      - "3000:3000"
    depends_on:
      postgres:
        condition: service_healthy
      clickhouse:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://langfuse:langfuse@postgres:5432/langfuse
      NEXTAUTH_URL: http://localhost:3000
      NEXTAUTH_SECRET: replace-with-a-random-secret
      SALT: replace-with-a-random-salt
      ENCRYPTION_KEY: replace-with-a-64-char-hex-key
      CLICKHOUSE_URL: http://clickhouse:8123
      CLICKHOUSE_MIGRATION_URL: clickhouse://clickhouse:9000
      CLICKHOUSE_USER: default
      CLICKHOUSE_PASSWORD: clickhouse
      CLICKHOUSE_CLUSTER_ENABLED: "false"
      REDIS_HOST: redis
      REDIS_PORT: "6379"
      LANGFUSE_S3_EVENT_UPLOAD_BUCKET: langfuse-events
      LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT: http://minio:9000
      LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID: minioadmin
      LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY: minioadmin
      LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE: "true"

  langfuse-worker:
    image: dhi.io/langfuse-worker:<tag>
    ports:
      - "3030:3030"
    depends_on:
      postgres:
        condition: service_healthy
      clickhouse:
        condition: service_healthy
      redis:
        condition: service_healthy
      minio:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://langfuse:langfuse@postgres:5432/langfuse
      ENCRYPTION_KEY: replace-with-a-64-char-hex-key
      SALT: replace-with-a-random-salt
      CLICKHOUSE_URL: http://clickhouse:8123
      CLICKHOUSE_USER: default
      CLICKHOUSE_PASSWORD: clickhouse
      REDIS_HOST: redis
      REDIS_PORT: "6379"
      LANGFUSE_S3_EVENT_UPLOAD_BUCKET: langfuse-events
      LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT: http://minio:9000
      LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID: minioadmin
      LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY: minioadmin
      LANGFUSE_S3_EVENT_UPLOAD_FORCE_PATH_STYLE: "true"
    healthcheck:
      test:
        [
          "CMD",
          "node",
          "-e",
          "require('http').get('http://localhost:3030/api/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))",
        ]
      interval: 15s
      timeout: 5s
      retries: 5

volumes:
  postgres-data:
  clickhouse-data:
  redis-data:
  minio-data:
```

Replace the placeholder secret values with values generated by `openssl rand -base64 32` (for string secrets) and
`openssl rand -hex 32` (for the 64-character hex `ENCRYPTION_KEY`). The worker does not run database migrations; the
`langfuse` web service handles that on startup.

### Environment variables

Only the most common variables are listed below. The full configuration reference is maintained upstream at
<https://langfuse.com/self-hosting/configuration>.

| Variable                                     | Description                                                      | Required  |
| -------------------------------------------- | ---------------------------------------------------------------- | --------- |
| `DATABASE_URL`                               | PostgreSQL connection URL. Credentials must be percent-encoded.  | Yes       |
| `ENCRYPTION_KEY`                             | 64-character hex key for symmetric encryption of stored secrets. | Yes       |
| `SALT`                                       | Random secret used for one-way hashing.                          | Yes       |
| `CLICKHOUSE_URL`                             | ClickHouse HTTP URL.                                             | Yes (v3+) |
| `CLICKHOUSE_USER`                            | ClickHouse username.                                             | Yes (v3+) |
| `CLICKHOUSE_PASSWORD`                        | ClickHouse password.                                             | Yes (v3+) |
| `REDIS_HOST`                                 | Redis hostname for the BullMQ job queue.                         | Yes       |
| `REDIS_PORT`                                 | Redis port. Defaults to `6379`.                                  | No        |
| `REDIS_CONNECTION_STRING`                    | Full Redis connection URL (alternative to host/port variables).  | No        |
| `LANGFUSE_S3_EVENT_UPLOAD_BUCKET`            | Object storage bucket used for event uploads.                    | Yes (v3+) |
| `LANGFUSE_S3_EVENT_UPLOAD_ENDPOINT`          | S3-compatible endpoint URL (required for MinIO or non-AWS S3).   | No        |
| `LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID`     | Access key for the object storage bucket.                        | No        |
| `LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY` | Secret key for the object storage bucket.                        | No        |

### Scaling and advanced self-hosting

For Kubernetes deployments, Helm-based topologies, horizontal scaling of the worker, and ClickHouse cluster
configuration, see the upstream self-hosting documentation: <https://langfuse.com/self-hosting>.

## Non-hardened images vs. Docker Hardened Images

The Docker Hardened Langfuse Worker image is functionally equivalent to the upstream
`docker.io/langfuse/langfuse-worker` image and accepts the same environment-variable configuration. The notable runtime
differences are:

- The worker application is installed at `/usr/lib/nodejs/langfuse-worker` and is symlinked to `/app/worker`. The
  default command (`node worker/dist/index.js`) works without change because the symlink preserves the path that
  upstream expects.
- The runtime image runs as UID 65532 (nonroot). The upstream image runs as UID 1001 (`expressjs`). Volume mounts or
  file permissions tied to UID 1001 must be updated.
- The runtime image contains no package manager and no general-purpose shell utilities. Custom `docker exec` workflows
  that rely on those binaries must be updated — use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/)
  or the `-dev` variant instead.

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
