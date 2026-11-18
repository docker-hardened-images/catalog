## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/zitadel:4`
- Mirrored image: `<your-namespace>/dhi-zitadel:4`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

The `4` tag is the Debian 13 runtime for the 4.x line. Use a detailed tag such as `4.20.3-debian13` to pin an exact
release, or an Alpine tag such as `4-alpine3.24`.

ZITADEL stores its data in PostgreSQL 17. The examples run PostgreSQL in a container on the same Docker network.
Configuration and deployment guidance is at https://zitadel.com/docs.

## Start a ZITADEL image

The runtime image runs `/app/zitadel` as UID 1000 and listens on port 8080. It has no shell. ZITADEL keeps its state in
PostgreSQL, so the container runs with a read-only root filesystem and no writable mounts.

### Basic usage

Create a network and start PostgreSQL. The credentials below are for local testing only. Use your own values elsewhere.

```bash
docker network create zitadel
docker run -d --name zitadel-postgres --network zitadel \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=zitadel \
  postgres:17-alpine
```

Wait until PostgreSQL accepts connections. The loop stops after 60 seconds:

```bash
timeout 60 sh -c 'until docker exec zitadel-postgres pg_isready -U postgres -d zitadel; do sleep 1; done'
```

Generate a 32-character master key and export it. ZITADEL uses this key to encrypt its data, so keep the value and reuse
it on every start against the same database:

```bash
export ZITADEL_MASTERKEY="$(openssl rand -hex 16)"
```

Start ZITADEL. The first start applies the database migrations, which can take up to a minute:

```bash
docker run -d --name zitadel --network zitadel -p 8080:8080 \
  --read-only \
  -e ZITADEL_MASTERKEY \
  -e ZITADEL_DATABASE_POSTGRES_HOST=zitadel-postgres \
  -e ZITADEL_DATABASE_POSTGRES_PORT=5432 \
  -e ZITADEL_DATABASE_POSTGRES_DATABASE=zitadel \
  -e ZITADEL_DATABASE_POSTGRES_USER_USERNAME=postgres \
  -e ZITADEL_DATABASE_POSTGRES_USER_PASSWORD=postgres \
  -e ZITADEL_DATABASE_POSTGRES_USER_SSL_MODE=disable \
  -e ZITADEL_DATABASE_POSTGRES_ADMIN_USERNAME=postgres \
  -e ZITADEL_DATABASE_POSTGRES_ADMIN_PASSWORD=postgres \
  -e ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_MODE=disable \
  -e ZITADEL_EXTERNALDOMAIN=localhost \
  -e ZITADEL_EXTERNALPORT=8080 \
  -e ZITADEL_EXTERNALSECURE=false \
  -e ZITADEL_TLS_ENABLED=false \
  -e ZITADEL_DEFAULTINSTANCE_FEATURES_LOGINV2_REQUIRED=false \
  dhi.io/zitadel:4 start-from-init --masterkeyFromEnv --tlsMode disabled
```

Wait for the health probe. It exits with status 0 once ZITADEL is ready. The loop stops after 3 minutes:

```bash
timeout 180 sh -c 'until docker exec zitadel /app/zitadel ready; do sleep 2; done'
```

Request the OpenID Connect discovery document:

```bash
curl -s http://localhost:8080/.well-known/openid-configuration
```

The response includes `"issuer":"http://localhost:8080"`. Use `localhost`, not `127.0.0.1`. ZITADEL only answers for the
host name set in `ZITADEL_EXTERNALDOMAIN`, and other host names return `404`.

Open the management console at `http://localhost:8080/ui/console/` in a browser.

To remove the containers and the network, run the following commands. The PostgreSQL container has no volume, so this
also deletes the database:

```bash
docker rm -f zitadel zitadel-postgres
docker network rm zitadel
```

### With Docker Compose

Save the following as `compose.yaml`. It starts PostgreSQL first and waits until it is healthy before it starts ZITADEL.
The master key comes from your shell environment, so it is not stored in the file.

```yaml
services:
  zitadel-postgres:
    image: postgres:17-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: zitadel
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d zitadel"]
      interval: 5s
      timeout: 3s
      retries: 20

  zitadel:
    image: dhi.io/zitadel:4
    command: ["start-from-init", "--masterkeyFromEnv", "--tlsMode", "disabled"]
    read_only: true
    depends_on:
      zitadel-postgres:
        condition: service_healthy
    ports:
      - "8080:8080"
    environment:
      ZITADEL_MASTERKEY: ${ZITADEL_MASTERKEY:?set ZITADEL_MASTERKEY to a 32-character value}
      ZITADEL_DATABASE_POSTGRES_HOST: zitadel-postgres
      ZITADEL_DATABASE_POSTGRES_PORT: "5432"
      ZITADEL_DATABASE_POSTGRES_DATABASE: zitadel
      ZITADEL_DATABASE_POSTGRES_USER_USERNAME: postgres
      ZITADEL_DATABASE_POSTGRES_USER_PASSWORD: postgres
      ZITADEL_DATABASE_POSTGRES_USER_SSL_MODE: disable
      ZITADEL_DATABASE_POSTGRES_ADMIN_USERNAME: postgres
      ZITADEL_DATABASE_POSTGRES_ADMIN_PASSWORD: postgres
      ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_MODE: disable
      ZITADEL_EXTERNALDOMAIN: localhost
      ZITADEL_EXTERNALPORT: "8080"
      ZITADEL_EXTERNALSECURE: "false"
      ZITADEL_TLS_ENABLED: "false"
      ZITADEL_DEFAULTINSTANCE_FEATURES_LOGINV2_REQUIRED: "false"
    healthcheck:
      test: ["CMD", "/app/zitadel", "ready"]
      interval: 10s
      timeout: 5s
      retries: 30
      start_period: 30s
```

Generate the key and start the stack. `--wait` returns only after every service reports `healthy`, or fails after 180
seconds. Then check the status of both services:

```bash
export ZITADEL_MASTERKEY="$(openssl rand -hex 16)"
docker compose up -d --wait --wait-timeout 180
docker compose ps
```

### Health probe

`/app/zitadel ready` exits with status 0 when the server is ready and with status 1 otherwise. The probe follows
`ZITADEL_TLS_ENABLED`. With the default `true`, it checks HTTPS, so it reports `not ready` against the plain HTTP server
in these examples. Keep `ZITADEL_TLS_ENABLED=false` for plain HTTP.

### Environment variables

| Variable                                                                                                                           | Description                                                                                                                                     | Required            |
| ---------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| `ZITADEL_MASTERKEY`                                                                                                                | 32-character master key, read when the command includes `--masterkeyFromEnv`.                                                                   | Yes                 |
| `ZITADEL_DATABASE_POSTGRES_HOST`, `ZITADEL_DATABASE_POSTGRES_PORT`, `ZITADEL_DATABASE_POSTGRES_DATABASE`                           | PostgreSQL host, port and database name.                                                                                                        | Yes                 |
| `ZITADEL_DATABASE_POSTGRES_USER_USERNAME`, `ZITADEL_DATABASE_POSTGRES_USER_PASSWORD`, `ZITADEL_DATABASE_POSTGRES_USER_SSL_MODE`    | Credentials and SSL mode for the runtime database connection.                                                                                   | Yes                 |
| `ZITADEL_DATABASE_POSTGRES_ADMIN_USERNAME`, `ZITADEL_DATABASE_POSTGRES_ADMIN_PASSWORD`, `ZITADEL_DATABASE_POSTGRES_ADMIN_SSL_MODE` | Credentials and SSL mode for the admin connection that ZITADEL uses during startup and setup.                                                   | Yes                 |
| `ZITADEL_EXTERNALDOMAIN`, `ZITADEL_EXTERNALPORT`, `ZITADEL_EXTERNALSECURE`                                                         | Public host name, port and scheme that ZITADEL uses to build its URLs and issuer. Requests must use this host name. Use `false` for plain HTTP. | Yes                 |
| `ZITADEL_TLS_ENABLED`                                                                                                              | Defaults to `true`. Set to `false` to serve plain HTTP. The health probe follows this setting.                                                  | Yes, for plain HTTP |
| `ZITADEL_DEFAULTINSTANCE_FEATURES_LOGINV2_REQUIRED`                                                                                | Defaults to `true`, which sends sign-in to the Login V2 app. That app is not part of this image. Set to `false` to use the embedded login.      | Yes, for sign-in    |
| `ZITADEL_SERVICEPING_ENABLED`                                                                                                      | The image sets `false`. Upstream enables ServicePing by default. Set to `true` to turn it back on.                                              | No                  |

## Common ZITADEL use cases

### Check the version

```bash
docker run --rm dhi.io/zitadel:4 --version
```

The command prints `zitadel version v4.20.3`.

### Inspect files with the dev variant

The `-dev` variants include a shell and run as root. Use them to inspect files, and run the workload on the runtime tag.
This example uses the Alpine dev tag:

```bash
docker run --rm --entrypoint /bin/sh dhi.io/zitadel:4-alpine3.24-dev \
  -c 'ls -ldn /app /app/zitadel /home/zitadel'
```

The `/app/zitadel` entry is a symbolic link to `/usr/bin/zitadel`. Both `/app` and the binary are owned by UID 0.

## Non-hardened images vs. Docker Hardened Images

Upstream `ghcr.io/zitadel/zitadel:v4.20.3` runs `/app/zitadel` as user `zitadel`. Commands such as
`start-from-init --masterkeyFromEnv` work the same way in this image. The differences below matter when you migrate:

| Area              | Upstream image                                                                                                | This image                                                                                                                                    |
| ----------------- | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Tags              | `v4.20.3`, with a `v` prefix                                                                                  | `4.20.3` and `4`, without a `v` prefix. The binary still reports `zitadel version v4.20.3`.                                                   |
| Binary            | `/app/zitadel` is a regular file owned by UID 1000                                                            | `/app/zitadel` is a symbolic link to `/usr/bin/zitadel`. Both are owned by root, so the runtime user cannot change the binary.                |
| User              | `zitadel`, UID 1000, home `/`                                                                                 | `zitadel`, UID 1000, home `/home/zitadel`. The runtime image has no shell.                                                                    |
| ServicePing       | Enabled by default                                                                                            | Disabled with `ZITADEL_SERVICEPING_ENABLED=false`. Set `true` to turn it back on.                                                             |
| Login and tooling | Login V2 is a separate image (`ghcr.io/zitadel/zitadel-login`). The upstream `-debug` image is also separate. | Neither is included. Set `ZITADEL_DEFAULTINSTANCE_FEATURES_LOGINV2_REQUIRED=false` to use the embedded login. The Helm chart is not included. |

### FIPS variants

FIPS variants include `fips` in the tag, for example `dhi.io/zitadel:4-fips` and `dhi.io/zitadel:4-alpine3.24-fips`.
They set the OpenSSL FIPS configuration through `OPENSSL_CONF` and `SSL_CERT_FILE`.

The FIPS variant refuses bcrypt password hashes. When you create a user with a bcrypt `hashedPassword`, the FIPS variant
returns `Errors.Hash.NotSupported` (gRPC code 3), and the non-FIPS variant creates the user. Plan for users with bcrypt
hashes to set a new password on the FIPS variant.

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
