## Prerequisites

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
repository**, and then follow the on-screen instructions.

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Refer to the [upstream Apache Superset documentation](https://superset.apache.org/docs/intro) for configuration options,
feature coverage, database connector reference, and production deployment guidance.

## Start an Apache Superset instance

The image ships with no bootstrap logic of its own: Superset requires a metadata database with the Alembic schema
applied and at least one admin user before the web server is useful. The minimum trial uses a SQLite metadata DB
persisted to a volume. Replace `<tag>` with the image tag you want to run.

Generate a strong `SUPERSET_SECRET_KEY` and keep it stable across bootstrap and serve — sessions signed with one key are
rejected by another:

```bash
export SUPERSET_SECRET_KEY="$(openssl rand -base64 42)"
export SQLALCHEMY_DATABASE_URI="sqlite:////app/superset_home/superset.db"
```

Initialize the schema and create an admin user (one-shot, exits when done):

```bash
docker run --rm \
  -v superset-home:/app/superset_home \
  -e SUPERSET_SECRET_KEY \
  -e SQLALCHEMY_DATABASE_URI \
  --entrypoint /bin/sh \
  dhi.io/superset:<tag> -c '
    superset db upgrade
    superset fab create-admin \
      --username admin --firstname Admin --lastname User \
      --email admin@example.com --password admin
    superset init'
```

Start the web server:

```bash
docker run -d --name superset -p 8088:8088 \
  -v superset-home:/app/superset_home \
  -e SUPERSET_SECRET_KEY \
  -e SQLALCHEMY_DATABASE_URI \
  dhi.io/superset:<tag>
```

Superset is now available at `http://localhost:8088/`. Sign in with `admin` / `admin`.

For production deployments — Postgres metadata DB, Redis broker/cache, Celery workers, Docker Compose topology — follow
the [upstream installation guide](https://superset.apache.org/docs/installation/docker-compose).

## Common Apache Superset use cases

### Persist Superset's home directory

Superset writes uploaded data, generated reports, and (for the default backend) an on-disk SQLite database under
`/app/superset_home`. Mount a volume there to keep state across container restarts:

```bash
docker run -d -p 8088:8088 \
  -v superset-home:/app/superset_home \
  -e SUPERSET_SECRET_KEY \
  -e SQLALCHEMY_DATABASE_URI \
  dhi.io/superset:<tag>
```

### Provide a Superset configuration file

Drop a `superset_config.py` into `/app/pythonpath` and Superset loads it at startup:

```bash
docker run -d -p 8088:8088 \
  -v $(pwd)/superset_config.py:/app/pythonpath/superset_config.py:ro \
  -v superset-home:/app/superset_home \
  -e SUPERSET_SECRET_KEY \
  dhi.io/superset:<tag>
```

See the [upstream configuration reference](https://superset.apache.org/docs/configuration/configuring-superset) for all
available settings.

### Install additional database drivers

The runtime image ships drivers for PostgreSQL, MySQL, and SQLite. To connect to other data sources (Snowflake,
BigQuery, Redshift, and so on), add them in a build stage using the `-dev` variant and copy the Python virtualenv into
the runtime image:

```dockerfile
FROM dhi.io/superset:<tag>-dev AS builder
RUN /app/.venv/bin/pip install "snowflake-sqlalchemy>=1.5" "sqlalchemy-bigquery>=1.10"

FROM dhi.io/superset:<tag>
COPY --from=builder /app/.venv /app/.venv
```

For the full list of supported database connectors and their pip packages, see the
[upstream database driver matrix](https://superset.apache.org/docs/configuration/databases).

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature         | Non-hardened Apache Superset           | Docker Hardened Apache Superset                     |
| --------------- | -------------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities    | Minimal, hardened base with security patches        |
| Shell           | `bash` + common utilities              | `dash` only (POSIX `/bin/sh`); no `bash`            |
| Package manager | `apt` available                        | No package manager in runtime variants              |
| User            | Runs as the `superset` user (UID 1000) | Runs as the nonroot user (UID 65532)                |
| Attack surface  | Larger due to additional utilities     | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging            | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

Install extra database drivers or Python packages during a build stage using the `-dev` variant, then copy the
`/app/.venv` directory into a runtime image.

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

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                              |
| :----------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                   |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user (UID 65532). Ensure `/app/superset_home`, `/app/pythonpath`, and `/app/data` are writable by UID 65532.                                                                                                                           |
| Multi-stage build  | Use images with a `dev` tag for build stages (for example to add database drivers) and non-dev images for runtime.                                                                                                                                                                                          |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                          |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The default listen port is `8088`. Map it to any host port with `-p <host>:8088`. |
| Entry point        | The entry point is `/usr/local/bin/run-server.sh` (symlinked from `/usr/bin/run-server.sh` for scripts that expect that path). The Python virtualenv lives at `/app/.venv`; the `superset` CLI is at `/app/.venv/bin/superset`.                                                                             |
| Shell              | The runtime image ships `dash` as `/bin/sh`, not `bash`. Scripts that rely on bashisms (arrays, `[[ ]]`, process substitution) must be ported to POSIX or run under a `-dev` image in a multi-stage build.                                                                                                  |

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a full shell nor any tools for debugging. The recommended method
for debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers.

```bash
docker debug dhi.io/superset:<tag>
```

### Permissions

By default image variants intended for runtime run as the nonroot user (UID 65532). Ensure `/app/superset_home`,
`/app/pythonpath`, `/app/data`, and any mounted volumes are writable by that user.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. The default listen port is `8088`. Map it to any host port
with `-p <host>:8088`.

### No bash

The runtime image ships `dash` as `/bin/sh` only. Use `-dev` images in build stages to run bash-specific commands and
then copy the resulting artifacts into the runtime stage.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
