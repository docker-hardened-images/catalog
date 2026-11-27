## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/icingadb:1`
- Mirrored image: `<your-namespace>/dhi-icingadb:1`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Choose a release line

Two Icinga DB minor lines are published. The tags `1` and `1.6` (with their variant suffixes, for example `1.6-dev`)
point to the 1.6 line, which is the latest. The tag `1.5` (for example `1.5-dev`) points to the 1.5 line, its
predecessor. Pin `1.5` to keep a 1.5 database and its schema; move to `1.6` with the upgrade steps below. The
`*_PASSWORD_FILE` variables and the database-driven Icinga Notifications settings work on the 1.6 line only: the 1.5
daemon ignores them, so use `ICINGADB_DATABASE_PASSWORD` and `ICINGADB_REDIS_PASSWORD` for passwords there, and
configure notifications with `ICINGADB_NOTIFICATIONS_URL`, `ICINGADB_NOTIFICATIONS_USERNAME` and
`ICINGADB_NOTIFICATIONS_PASSWORD`.

## Start an Icinga DB image

Icinga DB is a background daemon and listens on no port. It needs two services: the Redis server that Icinga 2 writes
to, and a MySQL, MariaDB, or PostgreSQL database that Icinga DB Web reads. The image ships no configuration file, so you
configure it with `ICINGADB_*` environment variables, as with the upstream container image. The default command,
`icingadb --database-auto-import`, imports the database schema on first start when the database is empty.

For every option, see the
[Icinga DB configuration documentation](https://icinga.com/docs/icingadb/latest/doc/03-Configuration/).

### Start Redis, PostgreSQL, and Icinga DB

```bash
docker network create icinga

docker run -d --name redis-icingadb --network icinga \
  dhi.io/redis:7 redis-server --requirepass redis-secret

docker run -d --name postgres-icingadb --network icinga \
  -e POSTGRES_USER=icingadb \
  -e POSTGRES_PASSWORD=db-secret \
  -e POSTGRES_DB=icingadb \
  dhi.io/postgres:17

docker run -d --name icingadb --network icinga \
  -e ICINGADB_REDIS_HOST=redis-icingadb \
  -e ICINGADB_REDIS_PORT=6379 \
  -e ICINGADB_REDIS_PASSWORD=redis-secret \
  -e ICINGADB_DATABASE_TYPE=pgsql \
  -e ICINGADB_DATABASE_HOST=postgres-icingadb \
  -e ICINGADB_DATABASE_DATABASE=icingadb \
  -e ICINGADB_DATABASE_USER=icingadb \
  -e ICINGADB_DATABASE_PASSWORD=db-secret \
  dhi.io/icingadb:1
```

The `redis-server` arguments replace the Redis image's default configuration, which accepts only local connections, and
set a password so that Redis accepts clients from the network.

Icinga DB retries until PostgreSQL accepts connections, imports the schema, and then waits for Icinga 2:

```bash
docker logs icingadb
```

The log ends with these lines (timestamps removed):

```text
INFO    icingadb    The database schema was successfully imported
INFO    icingadb    Connecting to Redis at 'redis://redis-icingadb:6379'
INFO    icingadb    Waiting for Icinga 2 to write into Redis, please make sure you have started Icinga 2 and the Icinga DB feature is enabled
```

### Connect Icinga 2

Icinga DB starts synchronizing once Icinga 2 writes to the same Redis server through its
[Icinga DB feature](https://icinga.com/docs/icinga-2/latest/doc/14-features/#icinga-db). This example runs the upstream
`icinga/icinga2` image and enables the feature with a configuration file:

```bash
cat > icingadb.conf <<'EOF'
object IcingaDB "icingadb" {
  host = "redis-icingadb"
  port = 6379
  password = "redis-secret"
}
EOF

docker run -d --name icinga2 --network icinga \
  -e ICINGA_MASTER=1 \
  -v "$PWD/icingadb.conf:/data/etc/icinga2/features-enabled/icingadb.conf:ro" \
  icinga/icinga2:2.16.6
```

Within a few seconds, `docker logs icingadb` shows that Icinga DB took over and started the sync:

```text
INFO    heartbeat    Received Icinga heartbeat
INFO    icingadb     Taking over    {"reason": "no other instance is active"}
INFO    icingadb     Starting config sync
```

### Environment variables

These are the variables a minimal setup needs. Other options, such as TLS, logging, and history retention, follow the
same pattern: `ICINGADB_`, the module name, and the option name, all in uppercase.

| Variable                          | Description                                                                            | Default                                | Required |
| --------------------------------- | -------------------------------------------------------------------------------------- | -------------------------------------- | -------- |
| `ICINGADB_REDIS_HOST`             | Host of the Redis server that Icinga 2 writes to.                                      | None                                   | Yes      |
| `ICINGADB_REDIS_PORT`             | Redis port.                                                                            | `6380`                                 | No       |
| `ICINGADB_REDIS_PASSWORD`         | Redis password.                                                                        | None                                   | No       |
| `ICINGADB_REDIS_PASSWORD_FILE`    | File that contains the Redis password. Use instead of `ICINGADB_REDIS_PASSWORD`.       | None                                   | No       |
| `ICINGADB_DATABASE_TYPE`          | `mysql` for MySQL or MariaDB, `pgsql` for PostgreSQL.                                  | `mysql`                                | No       |
| `ICINGADB_DATABASE_HOST`          | Database host.                                                                         | None                                   | Yes      |
| `ICINGADB_DATABASE_PORT`          | Database port.                                                                         | `3306` for `mysql`, `5432` for `pgsql` | No       |
| `ICINGADB_DATABASE_DATABASE`      | Database name.                                                                         | None                                   | Yes      |
| `ICINGADB_DATABASE_USER`          | Database user.                                                                         | None                                   | Yes      |
| `ICINGADB_DATABASE_PASSWORD`      | Database password.                                                                     | None                                   | No       |
| `ICINGADB_DATABASE_PASSWORD_FILE` | File that contains the database password. Use instead of `ICINGADB_DATABASE_PASSWORD`. | None                                   | No       |

Two defaults often cause a failed first start:

- The Redis port defaults to `6380`, the port of the `icingadb-redis` package. A standard Redis server listens on
  `6379`, so set `ICINGADB_REDIS_PORT=6379`, or Icinga DB keeps logging `Can't connect to Redis. Retrying` for port
  `6380`.
- The database type defaults to `mysql`. Without `ICINGADB_DATABASE_TYPE=pgsql`, Icinga DB connects to a PostgreSQL host
  on port `3306` and keeps logging `Can't connect to database. Retrying`.

## Common Icinga DB use cases

### Read passwords from files

To keep passwords out of `docker inspect` output, mount them as files and point the `*_PASSWORD_FILE` variables at them.
This needs the 1.6 line; the 1.5 daemon ignores the `*_PASSWORD_FILE` variables. This replaces the `icingadb` container
from the quick start:

```bash
printf '%s' 'redis-secret' > redis-password
printf '%s' 'db-secret' > db-password
chmod 0644 redis-password db-password

docker stop icingadb
docker rm icingadb
docker run -d --name icingadb --network icinga \
  -v "$PWD/redis-password:/run/secrets/redis-password:ro" \
  -v "$PWD/db-password:/run/secrets/db-password:ro" \
  -e ICINGADB_REDIS_HOST=redis-icingadb \
  -e ICINGADB_REDIS_PORT=6379 \
  -e ICINGADB_REDIS_PASSWORD_FILE=/run/secrets/redis-password \
  -e ICINGADB_DATABASE_TYPE=pgsql \
  -e ICINGADB_DATABASE_HOST=postgres-icingadb \
  -e ICINGADB_DATABASE_DATABASE=icingadb \
  -e ICINGADB_DATABASE_USER=icingadb \
  -e ICINGADB_DATABASE_PASSWORD_FILE=/run/secrets/db-password \
  dhi.io/icingadb:1
```

Two rules apply to these files:

- Icinga DB uses the whole file content as the password. Write the file with `printf '%s'`. `echo` adds a trailing
  newline, which becomes part of the password, and the database then rejects the login with
  `password authentication failed`.
- The runtime image runs as UID 65532, so the file must be readable by that UID. A file with mode `0600` that belongs to
  another user, such as UID 1001 from the upstream image, stops the daemon with
  `reading password file "/run/secrets/db-password" failed: open /run/secrets/db-password: permission denied`. To keep a
  file private on the host instead of using mode `0644`, give group 65532 read access:
  `sudo chgrp 65532 db-password && chmod 0640 db-password`.

### Apply a database schema upgrade

`--database-auto-import` only imports the schema into an empty database. When a new Icinga DB release changes the
schema, you apply the upgrade yourself. Until you do, the daemon exits with an error such as
`unexpected database schema version: v5 (expected v6), please make sure you have applied all database migrations after upgrading Icinga DB`.

The image ships the upgrade files in `/usr/share/icingadb/schema/mysql/upgrades/` and
`/usr/share/icingadb/schema/pgsql/upgrades/`, named after the release that needs them. The runtime image has no shell or
`cat`, so print the file with the dev variant of the release you upgrade to and pipe it into the database client. Stop
the Icinga DB instances that use the database first, and apply only the upgrade files for releases newer than the one
that created your schema. The database from the quick start already has the current schema, so it needs no upgrade.

The following example creates a separate database, `icingadb_upgrade`, on the PostgreSQL server from the quick start and
loads the Icinga DB 1.5.1 schema from the upstream repository to stand in for a database that an Icinga DB 1.5 release
created. It then applies the 1.6.0 upgrade and starts Icinga DB on the upgraded database:

```bash
docker exec postgres-icingadb createdb -U icingadb icingadb_upgrade
curl -fsSL https://raw.githubusercontent.com/Icinga/icingadb/v1.5.1/schema/pgsql/schema.sql \
  | docker exec -i postgres-icingadb psql -q -v ON_ERROR_STOP=1 -U icingadb -d icingadb_upgrade

docker run --rm dhi.io/icingadb:1-dev cat /usr/share/icingadb/schema/pgsql/upgrades/1.6.0.sql \
  | docker exec -i postgres-icingadb psql -q -v ON_ERROR_STOP=1 --single-transaction -U icingadb -d icingadb_upgrade

docker exec postgres-icingadb psql -U icingadb -d icingadb_upgrade -tAc 'SELECT max(version) FROM icingadb_schema'
```

The last command prints `6`, the schema version of Icinga DB 1.6.0. With `ON_ERROR_STOP=1` and `--single-transaction`,
`psql` exits with an error and rolls the whole upgrade back if any statement fails, for example because the file was
already applied, so a partly applied upgrade can't look like a success.

Start Icinga DB on the upgraded database:

```bash
docker run -d --name icingadb-upgraded --network icinga \
  -e ICINGADB_REDIS_HOST=redis-icingadb \
  -e ICINGADB_REDIS_PORT=6379 \
  -e ICINGADB_REDIS_PASSWORD=redis-secret \
  -e ICINGADB_DATABASE_TYPE=pgsql \
  -e ICINGADB_DATABASE_HOST=postgres-icingadb \
  -e ICINGADB_DATABASE_DATABASE=icingadb_upgrade \
  -e ICINGADB_DATABASE_USER=icingadb \
  -e ICINGADB_DATABASE_PASSWORD=db-secret \
  dhi.io/icingadb:1
```

`docker logs icingadb-upgraded` shows `Connecting to Redis` and no schema error. If you skipped releases, apply each
upgrade file in release order. Run the upgrade as the database user that owns the Icinga DB tables. For details, see
[Upgrading Icinga DB](https://icinga.com/docs/icingadb/latest/doc/04-Upgrading/).

### Configure Icinga Notifications from the database

This needs the 1.6 line. Icinga DB can send host and service events to
[Icinga Notifications](https://icinga.com/docs/icinga-notifications/latest/). By default, Icinga DB Web configures this
integration through the database: Icinga DB reads the `url`, `default_relations`, and `icingaweb2_url` settings from the
database and applies changes within about 15 seconds, without a restart. When it takes over, Icinga DB logs
`Starting Icinga Notifications configuration sync`. The integration needs Icinga 2 2.16.6 or later.

Credentials are never read from the database. Set them with `ICINGADB_NOTIFICATIONS_USERNAME` and
`ICINGADB_NOTIFICATIONS_PASSWORD` or `ICINGADB_NOTIFICATIONS_PASSWORD_FILE`. A notifications option that you set as an
environment variable is locked and can't be changed from Icinga DB Web. To turn off configuration from the database, set
`ICINGADB_NOTIFICATIONS_SYNCHRONIZE_WITH_DATABASE=false`. The integration is then enabled only when
`ICINGADB_NOTIFICATIONS_URL` is set. On the 1.5 line, set `ICINGADB_NOTIFICATIONS_URL`,
`ICINGADB_NOTIFICATIONS_USERNAME` and `ICINGADB_NOTIFICATIONS_PASSWORD`; these turn the integration on, and no settings
are read from the database.

## Non-hardened images vs. Docker Hardened Images

The Docker Hardened Icinga DB image differs from the upstream `icinga/icingadb` image in the following ways:

| Item                    | Upstream `icinga/icingadb:1.6.0`                                  | Docker Hardened Image                                                                                                                                                                                        |
| :---------------------- | :---------------------------------------------------------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| User                    | Runs as `icinga`, UID and GID 1001.                               | Runtime variants run as `nonroot`, UID and GID 65532. Mounted password files, certificates, and keys must be readable by UID 65532. Dev variants run as root.                                                |
| Entry point and command | No entry point. The command is `icingadb --database-auto-import`. | Same. Arguments after the image name replace the whole command, so start them with `icingadb`, for example `docker run --rm dhi.io/icingadb:1 icingadb --version`.                                           |
| Schema files            | Only `schema.sql` for MySQL and PostgreSQL, in `/schema`.         | `schema.sql` and the upgrade files in `/usr/share/icingadb/schema`. `/schema` links to that directory, so the default `--database-schema-dir ./schema/` and paths written for the upstream image still work. |
| Binary                  | `/icingadb`, found through `PATH=/`.                              | `/usr/sbin/icingadb`, found through the standard `PATH`. `/icingadb` links to it, so commands that call `/icingadb` still work.                                                                              |

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
