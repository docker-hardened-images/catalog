## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/hatchet-lite:<tag>`
- Mirrored image: `<your-namespace>/dhi-hatchet-lite:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Hatchet Lite image

The image bundles the three binaries the lite distribution needs, plus the pre-built web UI:

- `hatchet-lite` — the all-in-one server combining engine, API, and static file server
- `hatchet-admin` — used at first start to generate config and seed credentials
- `hatchet-migrate` — applies database schema migrations
- `/static-assets` — the pre-built React web UI served on port `8081`

An entrypoint script runs migrations, generates initial config under `/config`, then launches the lite server.

## Start a Hatchet Lite image

Hatchet requires a PostgreSQL database. The quickest way to run the full stack is with Docker Compose.

### With Docker Compose

```yaml
services:
  postgres:
    image: dhi.io/postgres:<tag>
    environment:
      POSTGRES_USER: hatchet
      POSTGRES_PASSWORD: hatchet
      POSTGRES_DB: hatchet
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U hatchet"]
      interval: 5s
      timeout: 5s
      retries: 10
    volumes:
      - postgres-data:/var/lib/postgresql/data

  hatchet-lite:
    image: dhi.io/hatchet-lite:<tag>
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      DATABASE_URL: postgres://hatchet:hatchet@postgres:5432/hatchet?sslmode=disable
      SERVER_AUTH_COOKIE_DOMAIN: localhost
      SERVER_AUTH_COOKIE_INSECURE: "t"
      SERVER_URL: http://localhost:8888
      SERVER_GRPC_INSECURE: "t"
      SERVER_GRPC_BROADCAST_ADDRESS: localhost:7070
      SERVER_AUTH_SET_EMAIL_VERIFIED: "t"
    ports:
      - "8888:8888"
      - "7070:7070"
    volumes:
      - hatchet-config:/config

volumes:
  postgres-data:
  hatchet-config:
```

When no message-queue env vars are set, `hatchet-lite` defaults to a Postgres-backed queue (uses the same database as
the application data), so this single-container example needs no broker. To plug in RabbitMQ instead, set
`SERVER_MSGQUEUE_RABBITMQ_URL` and add a `rabbitmq` service.

The web UI is served at `http://localhost:8888`. The gRPC broadcast endpoint is `localhost:7070`.

### Environment variables

| Variable                         | Description                                                              | Default          | Required |
| -------------------------------- | ------------------------------------------------------------------------ | ---------------- | -------- |
| `DATABASE_URL`                   | PostgreSQL connection string used by migrate, admin quickstart, and lite | —                | Yes      |
| `HATCHET_CONFIG_DIR`             | Directory the entrypoint writes generated config to                      | `/config`        | No       |
| `LITE_STATIC_ASSET_DIR`          | Directory the lite server serves the bundled web UI from                 | `/static-assets` | No       |
| `LITE_FRONTEND_PORT`             | Port the bundled static file server listens on                           | `8081`           | No       |
| `LITE_RUNTIME_PORT`              | Port the lite reverse proxy listens on (web UI + API)                    | `8888`           | No       |
| `SERVER_MSGQUEUE_KIND`           | Message-queue backend (`postgres` or `rabbitmq`)                         | `postgres`       | No       |
| `SERVER_MSGQUEUE_RABBITMQ_URL`   | AMQP URL when `SERVER_MSGQUEUE_KIND=rabbitmq`                            | —                | No       |
| `SERVER_AUTH_COOKIE_DOMAIN`      | Host (and port, if needed) for the session cookie; required for the API  | —                | Yes\*    |
| `SERVER_AUTH_COOKIE_INSECURE`    | Allow session cookies over HTTP (`"t"` for local Compose)                | `false`          | No       |
| `SERVER_URL`                     | Public URL of the web UI and API (used for redirects and cookies)        | —                | Yes\*    |
| `SERVER_GRPC_INSECURE`           | Serve gRPC without TLS (`"t"` for local Compose)                         | `false`          | No       |
| `SERVER_GRPC_BROADCAST_ADDRESS`  | Address clients use for gRPC (host:port as published on the host)        | —                | Yes\*    |
| `SERVER_AUTH_SET_EMAIL_VERIFIED` | Mark new users' email verified (`"t"` for local quickstart)              | `false`          | No       |

\*Required for a first successful start with the Compose example above (same variables as
[upstream Hatchet Lite](https://docs.hatchet.run/self-hosting/hatchet-lite)).

Additional Hatchet server configuration (database, message queue, encryption keys, OAuth providers, …) is read from
`/config` once `hatchet-admin quickstart` has populated it. See the
[upstream configuration reference](https://docs.hatchet.run/self-hosting/configuration-options) for the full list.

## Common Hatchet Lite use cases

- Self-hosted Hatchet for development and evaluation
- A single-container Hatchet for small production deployments that don't justify the full multi-service stack
- A drop-in replacement for `ghcr.io/hatchet-dev/hatchet/hatchet-lite:v0.88.0` (pin the tag to match your deployed
  version) in existing Compose or Helm setups

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
| Entry point        | Same behavior as upstream (migrate → `hatchet-admin quickstart` → `hatchet-lite`), via `/usr/local/bin/docker-entrypoint.sh`. Binaries live under `/usr/local/bin/` instead of `/`.                                                                                                                                          |
| Base OS / user     | Debian 13 and nonroot (uid `65532`) instead of Alpine and root. Ensure `/config` bind mounts are writable by uid `65532`.                                                                                                                                                                                                    |
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
application running as the nonroot user can access them. The `/config` directory is owned by uid `65532`; host bind
mounts there must be writable by that user.

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
