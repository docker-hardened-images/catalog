## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Run a MariaDB container

Run the following command to run a MariaDB container. Replace `<tag>` with the image variant you want to run.

```bash
$ docker run --name some-mariadb -e MARIADB_ROOT_PASSWORD=my-secret-pw -d dhi.io/mariadb:<tag>
```

### Port binding

By default, the database within the container listens on port 3306. You can expose the container port to the host with
the `-p` flag:

```bash
$ docker run --name some-mariadb -p 3306:3306 -e MARIADB_ROOT_PASSWORD=my-secret-pw -d dhi.io/mariadb:<tag>
```

### Connect to MariaDB from the command line client

Run the MariaDB command line client against your container:

```bash
$ docker exec -it some-mariadb mariadb -uroot -p
```

### Using Docker Compose

Example `compose.yaml` for MariaDB:

```yaml
services:
  db:
    image: dhi.io/mariadb:<tag>
    restart: always
    environment:
      MARIADB_ROOT_PASSWORD: my-secret-pw
    volumes:
      - mariadb-data:/var/lib/mysql
volumes:
  mariadb-data:
```

## Environment variables

The MariaDB image uses the following environment variables for configuration. These variables only take effect when
initializing a new database. If you start the container with a data directory that already contains a database, these
variables are ignored.

### Required variables

| Variable                | Description                                                                                                       |
| :---------------------- | :---------------------------------------------------------------------------------------------------------------- |
| `MARIADB_ROOT_PASSWORD` | Sets the password for the MariaDB `root` superuser account. Required unless `MARIADB_ROOT_PASSWORD_FILE` is used. |

### Optional variables

| Variable                     | Description                                                                                                   |
| :--------------------------- | :------------------------------------------------------------------------------------------------------------ |
| `MARIADB_ROOT_PASSWORD_FILE` | Path to a file containing the root password. Use this instead of `MARIADB_ROOT_PASSWORD` for Docker secrets.  |
| `MARIADB_OPTIONS`            | Additional command-line options to pass to `mariadbd` (space-separated). For example: `--max-connections=50`. |

### Read-only environment variables (set by the image)

| Variable           | Description                                                                                   |
| :----------------- | :-------------------------------------------------------------------------------------------- |
| `MARIADB_DATA_DIR` | Path to the MariaDB data directory. Defaults to `/var/lib/mysql`. Do not override this value. |

### Using Docker secrets

You can load passwords from files using the `_FILE` suffix on environment variables. This is useful for Docker secrets
and other secret management systems.

**Using Docker Compose with secrets:**

```yaml
services:
  mariadb:
    image: dhi.io/mariadb:<tag>
    secrets:
      - mariadb_password
    environment:
      MARIADB_ROOT_PASSWORD_FILE: /run/secrets/mariadb_password
secrets:
  mariadb_password:
    file: ./mariadb-password.txt
```

**Using Docker run with a mounted file:**

```bash
$ docker run --name some-mariadb \
  -e MARIADB_ROOT_PASSWORD_FILE=/run/secrets/mariadb_password \
  -v /path/to/password-file:/run/secrets/mariadb_password:ro \
  -d dhi.io/mariadb:<tag>
```

### Passing MariaDB server options

Use the `MARIADB_OPTIONS` environment variable to pass additional options to the MariaDB server:

```bash
$ docker run --name some-mariadb \
  -e MARIADB_ROOT_PASSWORD=my-secret-pw \
  -e MARIADB_OPTIONS="--max-connections=50 --thread-cache-size=16" \
  -d dhi.io/mariadb:<tag>
```

Alternatively, pass options directly on the command line after `mariadbd`:

```bash
$ docker run --name some-mariadb \
  -e MARIADB_ROOT_PASSWORD=my-secret-pw \
  -d dhi.io/mariadb:<tag> mariadbd --max-connections=50
```

### Using a custom MariaDB configuration file

Custom configuration files should end in `.cnf` and be mounted read-only at `/etc/mysql/conf.d`:

```bash
$ docker run --name some-mariadb \
  -v /my/custom:/etc/mysql/conf.d:ro \
  -e MARIADB_ROOT_PASSWORD=my-secret-pw \
  -d dhi.io/mariadb:<tag>
```

### Configuration without a cnf file

Many configuration options can be passed as flags to `mariadbd`. For example, to run on port 3808:

```bash
$ docker run --name some-mariadb -e MARIADB_ROOT_PASSWORD=my-secret-pw -d dhi.io/mariadb:<tag> mariadbd --port 3808
```

## Data persistence

Mount a volume to persist MariaDB data across container restarts:

```bash
$ docker run --name some-mariadb \
  -e MARIADB_ROOT_PASSWORD=my-secret-pw \
  -v mariadb-data:/var/lib/mysql \
  -d dhi.io/mariadb:<tag>
```

The MariaDB data is stored in `/var/lib/mysql` inside the container.

## Creating database dumps

Use `mariadb-dump` to create backups:

```bash
$ docker exec some-mariadb mariadb-dump -uroot -p"$MARIADB_ROOT_PASSWORD" --all-databases > backup.sql
```

## Restoring from dumps

Restore a database from a SQL dump:

```bash
$ docker exec -i some-mariadb mariadb -uroot -p"$MARIADB_ROOT_PASSWORD" < backup.sql
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. These variants use cryptographic modules that have been
  validated under FIPS 140, a U.S. government standard for secure cryptographic operations. For example, usage of MD5
  fails in FIPS variants.

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
the host. For example, `docker run -p 3306:3306 my-image`.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
