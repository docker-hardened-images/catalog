## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/trigger-dev:<tag>`
- Mirrored image: `<your-namespace>/dhi-trigger-dev:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a trigger-dev container

The `dhi/trigger-dev` image runs the self-hosted Trigger.dev webapp (API server, scheduler, and dashboard). On startup
the image runs Prisma migrations against your Postgres database, optionally runs Goose migrations against ClickHouse,
and then starts the Node.js webapp on port 3000.

Trigger.dev requires a Postgres database that has logical replication enabled (`wal_level=logical`). The minimum set of
environment variables the webapp validates at startup is shown in the example below.

### Basic usage

```bash
$ docker run --rm \
  --name trigger-dev \
  -p 3000:3000 \
  -e DATABASE_URL="postgresql://trigger:trigger@host.docker.internal:5432/trigger?schema=public" \
  -e DIRECT_URL="postgresql://trigger:trigger@host.docker.internal:5432/trigger?schema=public" \
  -e SESSION_SECRET="$(openssl rand -hex 32)" \
  -e MAGIC_LINK_SECRET="$(openssl rand -hex 32)" \
  -e ENCRYPTION_KEY="$(openssl rand -hex 16)" \
  -e DEPLOY_REGISTRY_HOST="registry.example.com" \
  -e SKIP_CLICKHOUSE_MIGRATIONS=1 \
  -e CLICKHOUSE_URL="http://noop" \
  -e REDIS_HOST=host.docker.internal \
  -e REDIS_PORT=6379 \
  -e REDIS_TLS_DISABLED=true \
  dhi.io/trigger-dev:<tag>
```

Once the container is running, the webapp serves the dashboard at `http://localhost:3000` and a plain-text healthcheck
at `http://localhost:3000/healthcheck` (responds `OK` with HTTP 200 once Postgres is reachable).

The webapp connects to Redis at startup to bootstrap concurrency tracking and several internal queues, so a reachable
Redis is required for the container to stay up. Set `REDIS_TLS_DISABLED=true` when pointing at a Redis instance that
does not terminate TLS (most local development setups, including the Compose example below).

### With Docker Compose

The following Compose example brings up Postgres (with logical replication enabled), Redis, and the Trigger.dev webapp,
with ClickHouse migrations skipped so a single-node deployment can come up with just Postgres + Redis. Replace the
placeholder secrets before using this in any non-throwaway environment.

```yaml
services:
  postgres:
    image: dhi.io/postgres:17
    container_name: trigger-postgres
    # The dhi.io/postgres image's entrypoint already invokes `postgres`, so only
    # pass extra `-c` flags here.
    command: ["-c", "wal_level=logical"]
    environment:
      POSTGRES_USER: trigger
      POSTGRES_PASSWORD: trigger
      POSTGRES_DB: trigger
    ports:
      - "5432:5432"

  redis:
    image: dhi.io/redis:7
    container_name: trigger-redis
    # Disable protected mode so the webapp can connect over the Compose network
    # without configuring Redis auth.
    command: ["redis-server", "--protected-mode", "no"]
    ports:
      - "6379:6379"

  webapp:
    image: dhi.io/trigger-dev:<tag>
    container_name: trigger-webapp
    depends_on:
      - postgres
      - redis
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: "postgresql://trigger:trigger@postgres:5432/trigger?schema=public"
      DIRECT_URL: "postgresql://trigger:trigger@postgres:5432/trigger?schema=public"
      # DATABASE_HOST makes the entrypoint block until Postgres accepts TCP
      # connections, which avoids a race between Compose's `depends_on: started`
      # and Postgres finishing initialization.
      DATABASE_HOST: "postgres:5432"
      REDIS_HOST: redis
      REDIS_PORT: "6379"
      # The bundled Redis worker clients default to TLS; disable for the local
      # plaintext Redis above.
      REDIS_TLS_DISABLED: "true"
      # Replace the three secrets below before using this in any non-throwaway
      # environment. ENCRYPTION_KEY must be exactly 32 bytes; generate with
      # `openssl rand -hex 16` to get a 32-character hex string.
      SESSION_SECRET: "replace-with-32-byte-hex-secret"
      MAGIC_LINK_SECRET: "replace-with-32-byte-hex-secret"
      ENCRYPTION_KEY: "replace-with-32-char-hex-key-aaa"
      DEPLOY_REGISTRY_HOST: "registry.example.com"
      SKIP_CLICKHOUSE_MIGRATIONS: "1"
      CLICKHOUSE_URL: "http://noop"
```

### Required environment variables

The Trigger.dev webapp validates its environment on startup and exits if any of the following are missing or invalid.
See the upstream `apps/webapp/app/env.server.ts` for the authoritative list.

| Variable                     | Description                                                                                                                                                                                                         | Required |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| `DATABASE_URL`               | Postgres connection string used by the webapp (pgbouncer-friendly).                                                                                                                                                 | Yes      |
| `DIRECT_URL`                 | Postgres connection string used for migrations and replication slots.                                                                                                                                               | Yes      |
| `SESSION_SECRET`             | 32-byte hex secret used to sign session cookies.                                                                                                                                                                    | Yes      |
| `MAGIC_LINK_SECRET`          | 32-byte hex secret used for magic-link login tokens.                                                                                                                                                                | Yes      |
| `ENCRYPTION_KEY`             | 16-byte hex (32-character) key used for at-rest secret encryption.                                                                                                                                                  | Yes      |
| `DEPLOY_REGISTRY_HOST`       | Container registry host used for deployed task images.                                                                                                                                                              | Yes      |
| `CLICKHOUSE_URL`             | ClickHouse URL for the V4 events store.                                                                                                                                                                             | Yes      |
| `SKIP_CLICKHOUSE_MIGRATIONS` | Set to `1` to skip the embedded Goose migrations when running without ClickHouse.                                                                                                                                   | No       |
| `SKIP_POSTGRES_MIGRATIONS`   | Set to `1` to skip the Prisma `migrate deploy` step on container start.                                                                                                                                             | No       |
| `DATABASE_HOST`              | `host:port` (defaults to port `5432` if omitted). When set, the entrypoint blocks until the host accepts TCP connections before running migrations. Useful for orchestrators that don't gate on database readiness. | No       |
| `REDIS_HOST` / `REDIS_PORT`  | Redis coordinates for queues and pub/sub. The webapp exits at startup if Redis is unreachable.                                                                                                                      | Yes      |
| `REDIS_TLS_DISABLED`         | Set to `true` when connecting to a Redis without TLS (most local/dev setups).                                                                                                                                       | No       |
| `NODE_MAX_OLD_SPACE_SIZE`    | Override Node's `--max-old-space-size` (defaults to `8192`).                                                                                                                                                        | No       |

Trigger.dev exposes many additional configuration variables (S3-compatible object storage, OAuth providers, Sentry,
worker tuning, etc.). See the upstream Trigger.dev self-hosting guide at https://trigger.dev/docs/self-hosting/overview
for the complete reference.

## Common trigger-dev use cases

### Running migrations against an external Postgres

The image's entrypoint runs `prisma migrate deploy` on every start. To run migrations as a one-off without starting the
webapp, override the entrypoint on the dev variant:

```bash
$ docker run --rm \
  -e DATABASE_URL="postgresql://trigger:trigger@host.docker.internal:5432/trigger?schema=public" \
  -e DIRECT_URL="postgresql://trigger:trigger@host.docker.internal:5432/trigger?schema=public" \
  --entrypoint /triggerdotdev/node_modules/.bin/prisma \
  dhi.io/trigger-dev:<tag>-dev \
  migrate deploy --schema /triggerdotdev/internal-packages/database/prisma/schema.prisma
```

### Running ClickHouse schema migrations with Goose

When `CLICKHOUSE_URL` is set and `SKIP_CLICKHOUSE_MIGRATIONS` is not `1`, the entrypoint runs the bundled
`/usr/local/bin/goose` against `internal-packages/clickhouse/schema`. To run migrations explicitly without starting the
webapp, override the entrypoint on the dev variant:

```bash
$ docker run --rm \
  -e GOOSE_DRIVER=clickhouse \
  -e GOOSE_DBSTRING="tcp://default:@clickhouse:9000/default?secure=true" \
  --entrypoint /usr/local/bin/goose \
  dhi.io/trigger-dev:<tag>-dev \
  -dir /triggerdotdev/internal-packages/clickhouse/schema up
```

### Health-checking the webapp

The webapp serves a plain-text healthcheck at `/healthcheck` that returns `OK` with HTTP 200 once Postgres is reachable.
Use it as a Kubernetes readiness probe or as a Compose healthcheck sidecar:

```yaml
  healthcheck-sidecar:
    image: dhi.io/busybox:1
    depends_on:
      - webapp
    command:
      - sh
      - -c
      - "until wget -q -O - http://webapp:3000/healthcheck | grep -q OK; do sleep 2; done"
```

## Non-hardened images vs. Docker Hardened Images

The DHI `trigger-dev` image differs from upstream `ghcr.io/triggerdotdev/trigger.dev` in a few intentional ways:

- **Runs as nonroot.** The webapp process runs as UID/GID `65532:65532` (instead of upstream's `node` user, UID/GID
  `1000:1000`). The image's working directory `/triggerdotdev` and the per-start writable subdirectory
  `/triggerdotdev/apps/webapp/prisma` are owned by this user. If you bind-mount writable state into the container,
  ensure the host directory is writable by UID `65532` — volumes previously chowned for upstream's UID `1000` will need
  re-chowning.
- **No shell or package manager in the runtime variant.** The runtime image ships only the binaries needed by the
  entrypoint (`dumb-init`, `node`, `goose`, `nc.openbsd`, `prisma` from `node_modules/.bin`, plus `dash`, `coreutils`,
  `grep`, and `sed` consumed by the entrypoint script and pnpm shims). For interactive debugging use the `-dev` tag or
  [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/).
- **Entrypoint wrapper invokes Prisma directly.** Upstream's entrypoint shells out to
  `pnpm --filter @trigger.dev/database db:migrate:deploy`, which requires `pnpm` at runtime. The DHI image invokes
  Prisma's CLI directly via `/triggerdotdev/node_modules/.bin/prisma` and uses `nc.openbsd` for the optional
  `DATABASE_HOST` wait loop. Behavior parity is preserved: Prisma migrations run, then optional Goose ClickHouse
  migrations, then the webapp starts.
- **FIPS variants apply to Node and Go.** The `-fips` and `-fips-dev` tags chain Docker's OpenSSL FIPS provider via
  `OPENSSL_CONF=/usr/lib/ssl/fips.cnf`, which declares a `nodejs_conf` section so Node's OpenSSL routes through the FIPS
  provider, and ship the embedded `goose` binary compiled against the FIPS Go toolchain with `GODEBUG=fips140=on`.
  `fips140=on` is used (rather than the strict `fips140=only`) because ClickHouse's default TLS cipher negotiation may
  include X25519, which is not FIPS-approved in strict mode.

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
