## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/harbor-db:<tag>`
- Mirrored image: `<your-namespace>/dhi-harbor-db:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this harbor-db image

This Docker Hardened harbor-db image includes:

- **postgres** — The PostgreSQL 15 database server daemon
- **psql** — The PostgreSQL interactive terminal and command-line client
- **pg_dump** / **pg_restore** — Backup and restore utilities
- **pg_upgrade** — In-place upgrade utility (PostgreSQL 14 to 15)
- **Harbor initialization scripts** — Automatic database and schema setup on first start
- **Healthcheck script** — Verifies the database is accepting connections

## Start a harbor-db image

Harbor DB is designed to run as a component within a full Harbor deployment. The image ships with a custom entrypoint
that handles database initialization and upgrades automatically.

### Basic usage

Run Harbor DB with a named volume for data persistence:

```bash
$ docker run -d --name harbor-db \
  -p 5432:5432 \
  -e POSTGRES_PASSWORD=changeit \
  -v harbor-db-data:/var/lib/postgresql/data \
  dhi.io/harbor-db:<tag>
```

> **Note:** A named volume (`-v harbor-db-data:...`) is required. Unlike the upstream `goharbor/harbor-db` image, this
> image does not declare a `VOLUME` in its metadata, so Docker will not automatically create an anonymous volume.
> Without an explicit volume mount, data is lost when the container is removed.
>
> This image also does not embed a `HEALTHCHECK` in its metadata. To monitor database health, configure a healthcheck
> externally as shown in the Docker Compose example below, or use `docker exec harbor-db /docker-healthcheck.sh`
> manually.

### With Docker Compose (recommended for Harbor deployments)

In a Harbor deployment, the database service is typically defined alongside the other Harbor components. The following
example shows how to configure the Harbor DB service using the DHI image:

```yaml
services:
  postgresql:
    image: dhi.io/harbor-db:<tag>
    container_name: harbor-db
    restart: always
    environment:
      POSTGRES_PASSWORD: changeit
    volumes:
      - harbor-db-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "/docker-healthcheck.sh"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 30s

volumes:
  harbor-db-data:
```

To replace `goharbor/harbor-db` in an existing Harbor `docker-compose.yml`, update the `postgresql` service's `image`
field:

```yaml
services:
  postgresql:
    image: dhi.io/harbor-db:<tag>   # replaces goharbor/harbor-db:<version>
```

### Environment variables

| Variable                   | Default                    | Description                                                                        |
| -------------------------- | -------------------------- | ---------------------------------------------------------------------------------- |
| `POSTGRES_PASSWORD`        | *(none)*                   | Password for the `postgres` superuser. Supports `_FILE` suffix for Docker secrets. |
| `POSTGRES_USER`            | `postgres`                 | Superuser name. Supports `_FILE` suffix.                                           |
| `POSTGRES_DB`              | `$POSTGRES_USER`           | Default database name. Supports `_FILE` suffix.                                    |
| `POSTGRES_MAX_CONNECTIONS` | `1024`                     | Maximum number of concurrent connections (capped at 262143).                       |
| `POSTGRES_INITDB_ARGS`     | *(none)*                   | Additional arguments passed to `initdb`.                                           |
| `PGDATA`                   | `/var/lib/postgresql/data` | Data directory root. Active data is stored under `$PGDATA/pg15/`.                  |

## Differences from upstream `goharbor/harbor-db`

This image is a drop-in replacement for `goharbor/harbor-db`, but there are important differences to be aware of when
migrating:

| Difference           | Upstream (`goharbor/harbor-db`)                    | This image                                                                                                                                                                                     |
| :------------------- | :------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base OS              | VMware Photon OS 5.0                               | Debian 13 (Trixie)                                                                                                                                                                             |
| PostgreSQL packages  | Photon `tdnf` packages                             | Binaries from the Docker Hardened `dhi/postgres` image, built from source.                                                                                                                     |
| PG binary paths      | `/usr/pgsql/{14,15}/bin/`                          | `/opt/postgresql/{14,15}/bin/`                                                                                                                                                                 |
| `VOLUME` declaration | `VOLUME /var/lib/postgresql/data` baked into image | Not declared. You must use `-v` or a named volume explicitly.                                                                                                                                  |
| `HEALTHCHECK`        | `CMD /docker-healthcheck.sh` baked into image      | Not declared. Configure healthchecks in your Compose file or orchestrator. The `/docker-healthcheck.sh` script is still included.                                                              |
| User (runtime)       | `postgres` (uid 999)                               | `postgres` (uid 70), matching `dhi/postgres`.                                                                                                                                                  |
| User (dev variant)   | `postgres` (uid 999)                               | Starts as `root`, then drops to `postgres` (uid 70) via `gosu` before running the entrypoint. This allows the dev variant to work with APT while still running PostgreSQL as the correct user. |
| Entrypoint           | `/docker-entrypoint.sh 14 15`                      | Same signature. The script is adapted for the `/opt/postgresql/` binary layout and adds `gosu` root-drop support.                                                                              |

**Data directory layout is unchanged:** `$PGDATA/pg15/` for the active cluster, `$PGDATA/pg14/` during upgrades.
Existing data volumes from upstream Harbor deployments are compatible.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

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

| Item               | Migration note                                                                                                                                                                               |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace `goharbor/harbor-db:<version>` with `dhi.io/harbor-db:<tag>`. See the differences table above for behavioral changes.                                                                |
| Volume             | You must explicitly mount a volume for `/var/lib/postgresql/data`. This image does not declare a `VOLUME`, so Docker will not create an anonymous volume automatically.                      |
| Healthcheck        | This image does not embed a `HEALTHCHECK`. Configure one in your Compose file or orchestrator using `/docker-healthcheck.sh`.                                                                |
| Package management | Runtime images do not contain a package manager. Use images with a `dev` tag for debugging or installing additional packages.                                                                |
| User               | Runtime images run as `postgres` (uid 70), matching `dhi/postgres`. Dev images start as `root` and drop to `postgres` via `gosu`.                                                            |
| Entry point        | The entrypoint signature is the same (`/docker-entrypoint.sh 14 15`). Internally, PostgreSQL binaries live under `/opt/postgresql/{14,15}/bin/`. No changes to how you invoke the container. |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                           |

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

This image runs as `postgres` (uid 70). If you mount custom configuration files or data volumes, ensure they are
readable by uid 70.

### PostgreSQL binary paths

PostgreSQL binaries are installed under `/opt/postgresql/{14,15}/bin/`, matching the Docker Hardened `dhi/postgres`
image layout, not `/usr/pgsql/{14,15}/bin/` (Photon layout). If you have scripts that reference PostgreSQL binary paths
directly, update them accordingly. The entrypoint and bundled scripts already use the correct paths.
