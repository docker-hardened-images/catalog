## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This image runs Percona Server for MySQL. On first start the entrypoint initializes the data directory, sets up the
`root` account, applies any requested database and user, and then execs `mysqld`. On subsequent starts an already
initialized data directory is detected and the server starts directly.

### What's included

The runtime variant contains the Percona Server binaries, `bash`, and the minimal set of shared libraries needed to run
the server. `bash` is present because the entrypoint is a shell script; a package manager is not included.

## Run the container

```bash
docker run -d --name percona \
  -e MYSQL_ROOT_PASSWORD=secret \
  -p 3306:3306 \
  dhi.io/percona:8
```

The default command is `mysqld`, so it can be omitted. Any arguments you pass are forwarded to `mysqld`:

```bash
docker run -d --name percona \
  -e MYSQL_ROOT_PASSWORD=secret \
  dhi.io/percona:8 --character-set-server=utf8mb4 --max-connections=500
```

Arguments that begin with a dash are treated as `mysqld` flags, so `mysqld` itself does not need to be repeated.

## Environment variables

| Variable                     | Description                                                                            |
| :--------------------------- | :------------------------------------------------------------------------------------- |
| `MYSQL_ROOT_PASSWORD`        | Password for the `root` account, set during initialization.                            |
| `MYSQL_ALLOW_EMPTY_PASSWORD` | Set to a non-empty value to allow an empty `root` password. Not recommended.           |
| `MYSQL_RANDOM_ROOT_PASSWORD` | Set to a non-empty value to generate a random `root` password and print it to the log. |
| `MYSQL_ROOT_HOST`            | Host part of the additional `root` account created at init. Defaults to `%`.           |
| `MYSQL_DATABASE`             | Name of a database created during initialization.                                      |
| `MYSQL_USER`                 | Additional user created during initialization. Requires `MYSQL_PASSWORD`.              |
| `MYSQL_PASSWORD`             | Password for `MYSQL_USER`.                                                             |
| `MYSQL_ONETIME_PASSWORD`     | Set to a non-empty value to expire the `root` password after initialization.           |
| `MYSQL_INITDB_SKIP_TZINFO`   | Set to a non-empty value to skip loading time zone tables.                             |
| `MYSQL_INIT_ONLY`            | Set to a non-empty value to initialize the data directory and exit without starting.   |

Exactly one of `MYSQL_ROOT_PASSWORD`, `MYSQL_ALLOW_EMPTY_PASSWORD`, or `MYSQL_RANDOM_ROOT_PASSWORD` must be set on first
start, otherwise the container exits with an error.

Each of `MYSQL_ROOT_PASSWORD`, `MYSQL_ROOT_HOST`, `MYSQL_DATABASE`, `MYSQL_USER`, and `MYSQL_PASSWORD` also accepts a
`_FILE` suffixed form that reads the value from a file, which suits Docker secrets:

```bash
docker run -d --name percona \
  -e MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql_root \
  -v ./root-password:/run/secrets/mysql_root:ro \
  dhi.io/percona:8
```

Setting both a variable and its `_FILE` form is an error.

## Initialization scripts

On first start only, files in `/docker-entrypoint-initdb.d/` are processed in name order. Files ending in `.sh` are
sourced, `.sql` files are piped into the client, and `.sql.gz` files are decompressed first. Other files are ignored.

```bash
docker run -d --name percona \
  -e MYSQL_ROOT_PASSWORD=secret \
  -v ./init:/docker-entrypoint-initdb.d:ro \
  dhi.io/percona:8
```

## Persisting data

The data directory is `/var/lib/mysql`. Mount a volume there to persist data across container restarts:

```bash
docker run -d --name percona \
  -e MYSQL_ROOT_PASSWORD=secret \
  -v percona-data:/var/lib/mysql \
  dhi.io/percona:8
```

The data directory is not hardcoded by the entrypoint. It is read from the server configuration, so a `datadir` set in a
mounted configuration file or passed as a `mysqld` flag is respected.

## FIPS mode

The `fips` variants start `mysqld` with `--ssl-fips-mode=ON` and use an OpenSSL FIPS 140 validated provider. The flag is
appended after any arguments you supply, so FIPS enforcement cannot be turned off through `mysqld` flags:

```bash
docker run -d --name percona \
  -e MYSQL_ROOT_PASSWORD=secret \
  dhi.io/percona:8-fips
```

## Differences from the upstream Percona image

This image accepts the same initialization environment variables and `/docker-entrypoint-initdb.d/` convention as the
upstream `percona` image, so most Compose files and Kubernetes manifests carry over unchanged. The following upstream
behaviors are intentionally not carried over:

- The Percona telemetry agent is not included, and the `PERCONA_TELEMETRY_*` variables have no effect.
- `INIT_TOKUDB` and `INIT_ROCKSDB` are not supported. TokuDB is not available in Percona Server 8.x.
- The server runs as a nonroot user (UID 65532) by default rather than as root. An existing `/var/lib/mysql` volume
  created by an image that ran the server as a different user must have its ownership updated before it can be reused.
- The runtime variant includes `bash` because the entrypoint is a shell script; a package manager is not included.

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
