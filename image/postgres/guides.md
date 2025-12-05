## How to use this image

### What's included in this PostgreSQL image

This Docker Hardened PostgreSQL image includes the complete PostgreSQL database system in a single, security-hardened
package.

To see the complete list of available PostgreSQL tools, you can check the `/usr/lib/postgresql/<VERSION>/bin/` directory
inside the container (replace `<VERSION>` with your PostgreSQL version, e.g., `15` or `16`).

Unlike some other DHI images where runtime variants contain only the main binary, the PostgreSQL runtime image includes
all PostgreSQL tools. This design decision delivers maximum operational flexibility:

- Database administration tasks require tools like `psql` in production
- Backup and restore operations need `pg_dump` and `pg_restore`
- Operational tasks often require these tools to be available
- This bundling provides a complete PostgreSQL toolkit in one security-hardened package

This approach aligns with real-world production use cases where PostgreSQL operations require more than just the server
binary.

## Start a PostgreSQL instance

Run the following command to run a PostgreSQL container. Replace `<your-namespace>` with your organization's namespace
and `<tag>` with the image variant you want to run.

```bash
docker run --name some-postgres -e POSTGRES_PASSWORD=mysecretpassword -d <your-namespace>/dhi-postgres:<tag>
```

## Common PostgreSQL use cases

### Basic PostgreSQL server with client access

Start the PostgreSQL:

```bash
docker run --name my-postgres -e POSTGRES_PASSWORD=mysecretpassword -d <your-namespace>/dhi-postgres:<tag>
```

Connect using the bundled `psql`:

```bash
docker exec -it my-postgres psql -U postgres
```

### PostgreSQL with network connectivity

Create a network and run PostgreSQL:

```bash
# Create a custom network
docker network create app-network

# Run PostgreSQL on the network
docker run --name my-postgres -d \
  --network app-network \
  -e POSTGRES_PASSWORD=mysecretpassword \
  <your-namespace>/dhi-postgres:<tag>
```

Applications running in Docker containers on the same network can now connect using 'my-postgres' as the hostname. For
example: `postgres://postgres:mysecretpassword@my-postgres:5432/postgres`.

If your application is running outside Docker, use `localhost` or `127.0.0.1` with the exposed port instead.

### Database backup and restore

Use the bundled tools for backup operations.

Create a backup:

```bash
docker exec my-postgres pg_dump -U postgres dbname > backup.sql
```

Restore a backup:

```bash
docker exec -i my-postgres psql -U postgres dbname < backup.sql
```

### Configure PostgreSQL with environment variables

The PostgreSQL image uses several environment variables for configuration:

**Required variables**

`POSTGRES_PASSWORD`: Sets the superuser password for PostgreSQL. This variable is required and must not be empty.

**Optional variables**

- `POSTGRES_USER`: Specifies a user with superuser privileges and creates a database with the same name. Defaults to
  `postgres` if not specified.
- `POSTGRES_DB`: Defines a different name for the default database. If not specified, uses the value of `POSTGRES_USER`.
- `POSTGRES_INITDB_ARGS`: Sends arguments to `postgres initdb` (space-separated string).
- `POSTGRES_INITDB_WALDIR`: Relocates `pg_wal` if specified. Equivalent to `--waldir` in `POSTGRES_INITDB_ARGS`.
- `POSTGRES_HOST_AUTH_METHOD`: Controls the auth-method for host connections. Supported values are `scram-sha-256` and
  `md5` (default). The values `trust` and `password` are not supported for security reasons.

**Note**: Authentication method restrictions are enforced only during database initialization by the entrypoint script.
If a database is initialized with another image and then run with the DHI, these security protections may be bypassed.

**Read-only environment variables (set by the image)**

- `PG_MAJOR`: Contains the PostgreSQL major version number (e.g., 15, 16, 17). This variable is automatically set by the
  image and should not be overridden.
- `PG_MINOR`: Contains the PostgreSQL minor version number. This variable is automatically set by the image and should
  not be overridden.
- `PGDATA`: Automatically set to `/var/lib/postgresql/<MAJOR_VERSION>/data`. While you can override this, it's
  recommended to use the default value.

The versioned PGDATA path ensures:

- Clear separation between different PostgreSQL major versions
- Easier upgrades and migrations
- Prevention of accidental data mixing between versions

Example with multiple environment variables:

```bash
docker run --name postgres-configured -d \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_INITDB_ARGS="--encoding=UTF8 --locale=C" \
  <your-namespace>/dhi-postgres:<tag>
```

## Stop PostgreSQL containers

The Docker Hardened PostgreSQL image is configured to use `SIGINT` as its stop signal instead of Docker's default
`SIGTERM`. This PostgreSQL-specific configuration ensures clean database shutdown with proper checkpoint completion.

### PostgreSQL shutdown modes

PostgreSQL responds to different signals with different shutdown behaviors:

- `SIGINT` (used by DHI): Initiates a "fast" shutdown. Refuses new connections, aborts active transactions, and performs
  a checkpoint before stopping.
- `SIGTERM` (OCI default): Initiates a "smart" shutdown. Waits for all clients to disconnect, which could take
  indefinitely.
- `SIGQUIT`: Forces immediate shutdown without checkpoint (not recommended).

### Stop containers for DHI

When you stop a DHI PostgreSQL container, Docker automatically sends `SIGINT` due to the image configuration:

```bash
docker stop my-postgres
```

Docker will:

1. Send `SIGINT` to PostgreSQL.
1. Wait for the stop timeout (default 10 seconds).
1. Force kill with `SIGKILL` if not stopped.

### Adjust stop timeout for large databases

For databases with significant data that need more checkopoint time, give PostgreSQL 30 seconds to complete shutdown:

```bash
docker stop -t 30 my-postgres
```

### Why this matters for data integrity

The `SIGINT` configuration ensures:

- All committed transactions are safely written to disk
- Proper checkpoint completion before shutdown
- Faster recovery on next startup
- Reduced risk of data corruption

This is especially important in production environments where data integrity is critical.

## Docker Official Images vs. Docker Hardened Images

### Key differences

| Feature         | Docker Official PostgreSQL          | Docker Hardened PostgreSQL                          |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as postgres user               | Runs as nonroot user for enhanced security          |
| Attack surface  | Larger due to additional utilities  | Minimal, only contains essential components         |
| PGDATA location | `/var/lib/postgresql/data`          | `/var/lib/postgresql/<MAJOR_VERSION>/data`          |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

## Why no package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a package manager nor any tools for debugging. Common debugging
methods for applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

For example, you can use Docker Debug:

```bash
docker debug my-postgres
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-postgres \
  --mount=type=image,source=<your-namespace>/dhi-busybox,destination=/dbg,ro \
  <your-namespace>/dhi-postgres:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| PGDATA path        | DHI PostgreSQL uses `/var/lib/postgresql/<MAJOR_VERSION>/data` instead of `/var/lib/postgresql/data`. Update volume mounts and backup scripts accordingly.                                                                                                                                                                   |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. **Install additional packages**.

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

1. **Update volume mounts for PGDATA**.

   Update any volume mounts to use the new versioned data directory:

   ```
   # Update docker-compose.yml or docker run commands
   volumes:
     - postgres-data:/var/lib/postgresql/16/data  # for PostgreSQL 16
   ```

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain any tools for debugging. The recommended method for debugging
applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

For PostgreSQL-specific debugging, you can still access PostgreSQL's built-in monitoring.

View active connections and queries:

```bash
docker exec my-postgres psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

Check PostgreSQL logs (location varies by configuration)"

```bash
docker logs my-postgres
```

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

For PostgreSQL, the data directory and configuration files must have appropriate ownership. The image handles this
automatically for the default PGDATA location, but custom mounted files may need permission adjustments.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

PostgreSQL's default port 5432 is not affected by this limitation and works without any special configuration.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

### PGDATA migration from Docker Official Images

When migrating existing PostgreSQL deployments from Docker Official Images or other PostgreSQL images (such as Bitnami
PostgreSQL, postgres:alpine, or custom images), you need to account for the different data directory location. Most
PostgreSQL images use `/var/lib/postgresql/data`, while DHI uses a versioned path.

#### Versioned PGDATA paths

The DHI PostgreSQL image uses a versioned data directory pattern (`/var/lib/postgresql/${PG_MAJOR}/data`) that's
automatically determined by the PostgreSQL major version in the image. This means:

- PostgreSQL 15.x images use `/var/lib/postgresql/15/data`
- PostgreSQL 16.x images use `/var/lib/postgresql/16/data`
- PostgreSQL 17.x images use `/var/lib/postgresql/17/data`
- PostgreSQL 18.x images use `/var/lib/postgresql/18/data`

This versioning is controlled by the `PG_MAJOR` environment variable that's built into the image. When writing scripts
or configurations, you may reference the version dynamically:

```bash
docker exec my-postgres sh -c 'echo "Data directory: $PGDATA"'
docker exec my-postgres sh -c 'echo "Major version: $PG_MAJOR"'
```

This helps prevent accidental data directory mismatches when upgrading PostgreSQL versions.

#### Migration options

For new deployments, use the versioned path when mounting volumes:

```bash
# Old (Docker Official)
-v postgres-data:/var/lib/postgresql/data

# New (Docker Hardened) - replace 16 with your major version
-v postgres-data:/var/lib/postgresql/16/data
```

For existing data migration, choose an option:

- Option 1: Data export/import (recommended for production)

  Export from old container:

  ```bash
  docker exec old-postgres pg_dumpall -U postgres > backup.sql
  ```

  Import to new DHI container:

  ```bash
  docker exec -i new-postgres psql -U postgres < backup.sql
  ```

- Option 2: Direct data copy

  Stop old container:

  ```bash
  docker post old-postgres
  ```

  Copy data to a new location (replace `16` with your major version):

  ```bash
  docker run --rm \
    -v old-postgres-data:/old \
    -v new-postgres-data:/new \
    busybox sh -c "cp -a /old/. /new/16/"
  ```

  Start new DHI container with new volume:

  ```bash
  docker run --name new-postgres -d \
    -e POSTGRES_PASSWORD=mysecretpassword \
    -v new-postgres-data:/var/lib/postgresql/16/data \
    <your-namespace>/dhi-postgres:16
  ```

  If your PostgreSQL container fails to start or you can't find your data, verify you're using the correct PGDATA path
  for your PostgreSQL major version.
