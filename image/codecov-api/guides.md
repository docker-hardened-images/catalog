## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Prerequisites

Codecov API is one service of a self-hosted Codecov deployment and needs the rest of the stack at runtime:

- PostgreSQL for the main database.
- TimescaleDB (PostgreSQL with the `timescaledb` extension) for the timeseries databases, when `setup.timeseries` or
  `setup.ta_timeseries` is enabled in the install configuration.
- Redis for caching and for the task queue shared with the Codecov worker.
- An S3-compatible object store (MinIO, S3 or GCS) for coverage reports.
- The Codecov worker, frontend and gateway services to complete a deployment.

The image bundles none of these. The [Codecov self-hosted repository](https://github.com/codecov/self-hosted) carries
the reference compose file and install configuration this image follows, and the
[Codecov configuration reference](https://docs.codecov.com/docs/configuration) documents every configuration key.

## Start a Codecov API instance

Codecov reads its install configuration from `/config/codecov.yml`, or from the path in `CODECOV_YML`. Any key can also
be set through the environment as `SECTION__KEY` (for example `SERVICES__DATABASE_URL`). A minimal `config/codecov.yml`
for a local stack:

```yaml
setup:
  codecov_url: http://localhost:8000
  enterprise_license: "<your-license-key>"
  http:
    cookie_secret: "<random-string>"
  timeseries:
    enabled: true
  ta_timeseries:
    enabled: true
services:
  redis_url: redis://redis:6379
  database_url: postgres://postgres:testpassword@postgres:5432/postgres
  timeseries_database_url: postgres://postgres:testpassword@timescale:5432/postgres
  ta_timeseries_database_url: postgres://postgres:testpassword@timescale:5432/postgres
django:
  secret_key: "<random-string>"
```

Django's `SECRET_KEY` defaults to a fixed value when `django.secret_key` is unset, so set it. Without a valid
`enterprise_license` the API starts, but the licence resolves as invalid with zero seats and no user can be activated;
upstream treats the key as required. Run the API next to its data stores with Compose:

```yaml
services:
  api:
    image: dhi.io/codecov-api:<tag>
    ports:
      - "127.0.0.1:8000:8000"
    volumes:
      - ./config:/config
    depends_on:
      postgres:
        condition: service_healthy
      timescale:
        condition: service_healthy
      redis:
        condition: service_healthy

  postgres:
    image: docker.io/postgres:17
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: testpassword
      POSTGRES_DB: postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres", "-d", "postgres"]
      interval: 5s
      retries: 20

  timescale:
    image: docker.io/timescale/timescaledb:latest-pg17
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: testpassword
      POSTGRES_DB: postgres
    volumes:
      - timescale-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres", "-d", "postgres"]
      interval: 5s
      retries: 20

  redis:
    image: docker.io/redis:7
    volumes:
      - redis-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      retries: 20

volumes:
  postgres-data:
  timescale-data:
  redis-data:
```

When `RUN_ENV` is `ENTERPRISE` (the default) or `DEV`, the entrypoint applies the Django migrations, the timeseries
migrations and the PostgreSQL partition setup on every start unless `CODECOV_SKIP_MIGRATIONS=true`; other `RUN_ENV`
values skip them. It then starts gunicorn on port 8000. `GET http://localhost:8000/health/` answers HTTP 200 with a body
ending in `is live!` once the API is serving. The API port is bound to the loopback interface above because the service
is meant to sit behind the Codecov gateway; expose it directly only on a trusted network.

### Environment variables

The entrypoint honours these variables; install-configuration keys are read from the configuration file or
`SECTION__KEY` variables.

| Variable                         | Description                                                                                                    | Default               |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------- | --------------------- |
| `RUN_ENV`                        | Selects the Django settings module. `ENTERPRISE` is the self-hosted mode.                                      | `ENTERPRISE`          |
| `CODECOV_YML`                    | Path of the install configuration file. Read by the application rather than the entrypoint.                    | `/config/codecov.yml` |
| `CODECOV_API_PORT`               | Port gunicorn listens on.                                                                                      | `8000`                |
| `CODECOV_API_BIND`               | Address gunicorn binds to.                                                                                     | `0.0.0.0`             |
| `CODECOV_SKIP_MIGRATIONS`        | Set to `true` to skip the migrations the entrypoint runs before starting.                                      | unset                 |
| `GUNICORN_WORKERS`               | gunicorn worker processes. More than one enables the Prometheus multiprocess directory.                        | `1`                   |
| `GUNICORN_THREADS`               | Threads per gunicorn worker.                                                                                   | `1`                   |
| `GUNICORN_WORKER_CONNECTIONS`    | Maximum simultaneous connections per gunicorn worker.                                                          | `1000`                |
| `GUNICORN_TIMEOUT`               | gunicorn worker timeout in seconds.                                                                            | `600`                 |
| `SHUTDOWN_TIMEOUT`               | Seconds to wait for gunicorn to drain on `SIGTERM` before it is killed.                                        | `25`                  |
| `STATSD_HOST`                    | StatsD host; adds `--statsd-host` to gunicorn. Requires `STATSD_PORT`.                                         | unset                 |
| `STATSD_PORT`                    | StatsD port, required when `STATSD_HOST` is set.                                                               | unset                 |
| `PROMETHEUS_MULTIPROC_DIR`       | Prometheus multiprocess directory, emptied and created on start. Used only when `GUNICORN_WORKERS` is above 1. | `$HOME/.prometheus`   |
| `CODECOV_WRAPPER`                | Command prefixed to every python command the entrypoint runs (migrations and gunicorn).                        | unset                 |
| `CODECOV_WRAPPER_POST`           | Arguments appended to every python command the entrypoint runs.                                                | unset                 |
| `CODECOV_WRAPPER_IGNORE_MIGRATE` | When set, the migration commands run without `CODECOV_WRAPPER` and `CODECOV_WRAPPER_POST`.                     | unset                 |

## Common Codecov API use cases

### Run a management command

Passing a command to the image runs it inside the application environment instead of starting gunicorn. Skip the
entrypoint's own migration step when the command should run on its own:

```bash
$ docker run --rm --network <stack-network> -v ./config:/config \
    -e CODECOV_SKIP_MIGRATIONS=true \
    dhi.io/codecov-api:<tag> python manage.py showmigrations
```

The same form runs the migrations as a separate job before rolling out a new API version:

```bash
$ docker run --rm --network <stack-network> -v ./config:/config \
    -e CODECOV_SKIP_MIGRATIONS=true \
    dhi.io/codecov-api:<tag> bash -c './migrate.sh && ./migrate-timeseries.sh'
```

`migrate.sh` and `migrate-timeseries.sh` come from upstream and are executable in this image. They run the Django
migrations and partition setup and the timeseries migrations, the same steps the entrypoint runs.

### Validate a repository `codecov.yml`

The API validates a repository `codecov.yml` (not the install configuration) without authentication:

```bash
$ curl -X POST --data-binary @- http://localhost:8000/validate <<'EOF'
coverage:
  status:
    project:
      default:
        target: 80%
EOF
```

### Health checks and metrics

`/health/` returns HTTP 200 and a body ending in `is live!` when the API can reach its database, and
`/monitoring/metrics` exposes Prometheus metrics. Runtime images carry no `curl`, so probe from the orchestrator:

```yaml
readinessProbe:
  httpGet:
    path: /health/
    port: 8000
  periodSeconds: 5
```

## FIPS scope

The FIPS variants load the OpenSSL FIPS provider for the system `libcrypto`. Python's `ssl`, `hashlib` and `hmac`
modules, the system `libpq` behind `psycopg2` and the `cryptography` package (built from source against the system
OpenSSL rather than the wheel's bundled copy) all use it, so Django's password hashing and session signing, outbound
HTTPS through `requests`, `httpx` and `urllib3`, TLS to PostgreSQL, JWT signing, the AES encryption of the enterprise
licence and of stored VCS tokens, and X.509 handling run through the validated module. MD5 fails; the application's own
non-security MD5 uses (report storage paths, the GraphQL `hashedPath` fields and avatar URLs) are marked as such so they
keep working, and any other MD5 use raises.

Outside that boundary: `grpcio` bundles BoringSSL and is used only by the Google Cloud Pub/Sub publisher when that
integration is configured; `pycryptodome` ships its own primitives as a dependency of the `minio` client; `argon2-cffi`
provides the Argon2 password hasher, which is not the default (PBKDF2 through `hashlib` is); `rsa` is google-auth's
pure-Python fallback; `polars` carries its own Rust TLS stack, is not imported by the API and is absent from the alpine
variants.

## Non-hardened images vs. Docker Hardened Images

- The application is installed from the `dhi/pkg-codecov-api` package at `/usr/share/codecov-api` with its Python
  environment at `/usr/lib/codecov-api`. Upstream copies the whole `umbrella` monorepo to `/app` and runs from
  `/app/apps/codecov-api`; that path is kept as a symlink, and `python` and `gunicorn` on `PATH` resolve to the packaged
  environment.
- The image runs as uid 65532 with `HOME=/home/nonroot`; upstream runs as the `codecov` user (uid 1001). Bind-mounted
  configuration must be readable by uid 65532.
- Only the `codecov-api` dependency group of the upstream lockfile is installed. Worker-only packages upstream's shared
  requirements image carries (`lxml`, `openai`, `test-results-parser`, ...) are absent, as are the `psycopg2-binary` and
  `tlslite-ng` copies upstream adds under `external_deps`. The locked `psycopg2-binary` is built from its source
  distribution against the system `libpq` instead of the bundled wheel, and `cryptography` is built from source against
  the system OpenSSL instead of the wheel's bundled copy, so PostgreSQL connections and the `cryptography` primitives
  use the system libraries.
- The alpine variants install the same locked set without `polars`, which publishes no musl wheel and which the API
  never imports; `codecov-ribs`, which publishes no musl wheel either, is built there from its source distribution.
- The packaged entrypoint carries a one-line fix to the upstream shutdown loop so `SIGTERM` drains gunicorn for
  `SHUTDOWN_TIMEOUT` seconds before it is killed. `migrate.sh` and `migrate-timeseries.sh` are executable, as in the
  upstream image, and the work directory is the upstream path `/app/apps/codecov-api`, which resolves to
  `/usr/share/codecov-api`.
- The runtime image ships `bash` and `coreutils` because the upstream entrypoint is a bash script; it ships no other
  shell tooling and no package manager.

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
