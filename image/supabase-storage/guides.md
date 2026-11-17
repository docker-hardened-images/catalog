## How to use this image

Supabase Storage is a long-running HTTP service with two external dependencies:

- a **PostgreSQL** database, which holds bucket and object metadata. It has to be reachable when the container starts.
  If it is not, the service exits.
- a **storage backend** for object data: any S3-compatible service, or a mounted filesystem path. It is first contacted
  on the first object request, not at startup, so a missing bucket shows up as a failed upload rather than a container
  that will not start.

The object APIs are served on port `5000`. There is also an admin API on port `5001`, but it only starts when
`MULTI_TENANT=true`. With the default single-tenant setup, nothing listens on 5001.

### Database setup

Supabase Storage applies its database migrations before it serves any request, and exits if they fail. Those migrations
expect a set of [Supabase Postgres roles](https://supabase.com/docs/guides/database/postgres/roles#supabase-roles) to
exist. A Supabase Postgres instance already has them; a stock `postgres` image does not, so set `DB_INSTALL_ROLES=true`
and the migrations create them, as
[upstream's Compose configuration](https://github.com/supabase/storage/blob/master/docker-compose.yml) does. Leave it at
`false` only if you manage those roles yourself.

If `/status` does not become ready, check the container logs for a migration failure.

## Start a Supabase Storage image

Supabase Storage always needs a PostgreSQL database, and an S3 bucket when `STORAGE_BACKEND=s3`, so a single container
is not enough. The example below uses Compose.

Create the S3 bucket yourself. The service does not create it, because the backend can be any S3-compatible service.
Upstream does the same, with a short `rustfs_setup` container that creates the bucket with a signed `curl` request and
exits.

### Docker Compose

```yaml
services:
  storage:
    image: dhi.io/supabase-storage:1
    depends_on:
      db:
        condition: service_healthy
      rustfs_setup:
        condition: service_completed_successfully
    ports:
      - "5000:5000"
    environment:
      AUTH_JWT_SECRET: super-secret-jwt-token-with-at-least-32-characters
      DATABASE_URL: postgresql://postgres:postgres@db:5432/postgres
      DB_INSTALL_ROLES: "true"
      UPLOAD_FILE_SIZE_LIMIT: "52428800"
      STORAGE_BACKEND: s3
      STORAGE_S3_BUCKET: storage
      STORAGE_S3_ENDPOINT: http://rustfs:9000
      STORAGE_S3_FORCE_PATH_STYLE: "true"
      STORAGE_S3_REGION: us-east-1
      AWS_ACCESS_KEY_ID: rustfsadmin
      AWS_SECRET_ACCESS_KEY: rustfsadmin

  db:
    image: postgres:16
    # Or use supabase/postgres, which ships the required roles already.
    environment:
      POSTGRES_PASSWORD: postgres
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 2s
      timeout: 5s
      retries: 15

  rustfs:
    image: rustfs/rustfs:1.0.0
    environment:
      RUSTFS_ACCESS_KEY: rustfsadmin
      RUSTFS_SECRET_KEY: rustfsadmin
      RUSTFS_ADDRESS: ":9000"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://127.0.0.1:9000/health/ready || exit 1"]
      interval: 2s
      timeout: 5s
      retries: 15

  # Creates the bucket named by STORAGE_S3_BUCKET, then exits.
  rustfs_setup:
    image: rustfs/rustfs:1.0.0
    depends_on:
      rustfs:
        condition: service_healthy
    entrypoint: >
      /bin/sh -c "curl -fsS --aws-sigv4 'aws:amz:us-east-1:s3' -u rustfsadmin:rustfsadmin -X PUT http://rustfs:9000/storage"
```

Once it is listening, `GET /status` returns `200`:

```console
$ curl -fsS -o /dev/null -w '%{http_code}\n' http://localhost:5000/status
200
```

### Environment variables

| Variable                      | Default          | Description                                                                                                                                                                                                                                                                                                                    |
| :---------------------------- | :--------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `AUTH_JWT_SECRET`             | *(required)*     | Secret used to verify request JWTs. `PGRST_JWT_SECRET` is accepted as an alias. Not required when `MULTI_TENANT=true`.                                                                                                                                                                                                         |
| `DATABASE_URL`                | *(required)*     | PostgreSQL connection string for object metadata. Not required when `MULTI_TENANT=true`.                                                                                                                                                                                                                                       |
| `DB_INSTALL_ROLES`            | `false`          | When `true`, the startup migrations create the roles described under [Database setup](#database-setup) instead of expecting them to exist already.                                                                                                                                                                             |
| `UPLOAD_FILE_SIZE_LIMIT`      | *(unset)*        | Global upload-size limit in bytes. Set this explicitly for standard uploads because the service has no built-in numeric default. `FILE_SIZE_LIMIT` is accepted as an alias.                                                                                                                                                    |
| `STORAGE_BACKEND`             | *(unset)*        | `s3` or `file`.                                                                                                                                                                                                                                                                                                                |
| `STORAGE_S3_BUCKET`           | *(unset)*        | Bucket holding object data when the backend is `s3`.                                                                                                                                                                                                                                                                           |
| `STORAGE_S3_ENDPOINT`         | *(unset)*        | S3 endpoint URL. Set this for RustFS or any other non-AWS implementation.                                                                                                                                                                                                                                                      |
| `STORAGE_S3_FORCE_PATH_STYLE` | `false`          | Use path-style addressing, which most S3-compatible services require.                                                                                                                                                                                                                                                          |
| `STORAGE_S3_REGION`           | *(unset)*        | Region passed to the S3 client.                                                                                                                                                                                                                                                                                                |
| `STORAGE_FILE_BACKEND_PATH`   | *(unset)*        | Directory holding object data when the backend is `file`. Use an absolute path outside `/app`, and mount a directory the nonroot user (uid/gid 65532) can write to; a relative value resolves inside the read-only application directory. The `s3` backend needs no writable mount.                                            |
| `SERVER_PORT`                 | `5000`           | Port for the object APIs. `PORT` is accepted as an alias.                                                                                                                                                                                                                                                                      |
| `SERVER_ADMIN_PORT`           | `5001`           | Port for the admin API. Bound only when `MULTI_TENANT=true`. `ADMIN_PORT` is accepted as an alias.                                                                                                                                                                                                                             |
| `SERVER_ADMIN_API_KEYS`       | *(unset)*        | Comma-separated keys authorizing the admin API. Requests to it return `401` without one.                                                                                                                                                                                                                                       |
| `MULTI_TENANT`                | `false`          | Serve multiple tenants; `DATABASE_MULTITENANT_URL` then holds the tenant registry.                                                                                                                                                                                                                                             |
| `VERSION`                     | set by the image | Version the service reports about itself.                                                                                                                                                                                                                                                                                      |
| `NODE_ENV`                    | `production`     | Set by the image, matching upstream's `npm start` script; the upstream image leaves it unset because its `CMD` calls `node` directly. Drains in-flight queue jobs on shutdown, and forces https in resumable-upload URLs. Pass `-e NODE_ENV=` for the upstream image's behaviour. See [Resumable uploads](#resumable-uploads). |

### Resumable uploads

The TUS endpoint at `/upload/resumable` returns the URL to send the `PATCH` to in a `Location` header. Because this
image sets `NODE_ENV=production`, that URL always uses `https`, ignoring `X-Forwarded-Proto` and `STORAGE_PUBLIC_URL`.
The upstream image leaves `NODE_ENV` unset and returns whichever scheme the request used, although upstream's own
`npm start` script does set it. Run TLS in front of the container, take the path from the returned URL and use it
against the address you connected to, or pass `-e NODE_ENV=` for the upstream image's behaviour.

`NODE_ENV=production` also changes shutdown: the container waits for running queue jobs before it stops.

Each part of a resumable upload is written to the system temp directory before it goes to the storage backend, so `/tmp`
has to stay writable. Both variants ship it with mode `1777`, so this only matters if you mount over it. S3 credentials
come from the AWS SDK default credential chain, so `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` work as shown above,
along with the SDK's other mechanisms.

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature          | Non-hardened upstream image (`supabase/storage-api`)                                          | Docker Hardened Supabase Storage                                                             |
| ---------------- | --------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| Base             | Alpine with a full Node.js installation                                                       | Debian or Alpine with only the packages needed to run the service                            |
| Entry point      | `docker-entrypoint.sh` from the `node` base image, with `CMD ["node","dist/start/server.js"]` | Entry point `node`, with `dist/start/server.js` as the command                               |
| Application path | `/app`                                                                                        | `/app`, which is a symlink to `/usr/lib/supabase-storage`. Relative paths work the same way. |
| Shell            | BusyBox `sh` available                                                                        | No shell in runtime variants                                                                 |
| User             | `root`                                                                                        | Default Docker Hardened Images `nonroot` user (uid/gid 65532)                                |
| Build tooling    | `g++`, `make`, and `python3` are left in the final image                                      | Build tools are used when the package is built and are not part of this image                |
| Debugging        | Shell inside the container                                                                    | Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) or similar tooling   |

### Entry point

The upstream image inherits `docker-entrypoint.sh` from its `node` base image. That script runs `node` for you when the
command you pass is not an executable, so `docker run <upstream-image> script.js` runs `node script.js`.

This image sets `node` as the entry point directly, so whatever you pass is appended to `node`. Passing a script still
works. Two other cases change:

- A command meant for `node` itself, such as `node -e '...'`, becomes `node node -e '...'` and fails. Drop the leading
  `node` and pass only its arguments: `docker run <image> -e '...'`.
- A command not meant for `node` at all, such as another binary, becomes `node <binary>` and fails. Override the entry
  point: `docker run --entrypoint <binary> <image>`.

### FIPS variants

The FIPS variants ship FIPS 140-validated cryptographic modules, the OpenSSL FIPS provider, and an entropy source at the
operating-system level. Node.js is built with its own copy of OpenSSL rather than the system one, so these variants do
not change which provider Node's built-in `crypto` module uses.

### Why no shell?

Docker Hardened Images prioritize a minimal runtime: fewer binaries, a smaller attack surface, and no interactive shell
in production images. For troubleshooting, use Docker Debug or mount debug tooling as described in
[Troubleshooting migration](#troubleshooting-migration).

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
