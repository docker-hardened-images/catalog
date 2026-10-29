## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/nominatim:<tag>`
- Mirrored image: `<your-namespace>/dhi-nominatim:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Nominatim image

This Docker Hardened Nominatim image is an all-in-one geocoding server. It includes:

- `nominatim`: the command-line tool to import, update, query, and administer the Nominatim database.
- `osm2pgsql`: loads OpenStreetMap data into PostgreSQL; `nominatim import` runs it.
- `psql`: the PostgreSQL terminal for the embedded PostgreSQL 17 and PostGIS database.

The API is served by gunicorn on port 8080. See the [Nominatim documentation](https://nominatim.org/release-docs/5.3/)
for the API and the administration commands.

## Start a Nominatim image

On first start the container downloads or reads an OpenStreetMap extract, imports it into the embedded database, and
then serves the API. Later starts on the same data skip the import. You must set exactly one of `PBF_URL` or `PBF_PATH`;
without either, the container prints an error and exits 1.

### Basic usage

This imports the Monaco extract, which takes about a minute:

```bash
$ docker run -d --name nominatim -p 8080:8080 \
  -e PBF_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf \
  dhi.io/nominatim:<tag>
```

Follow the logs until `--> Nominatim is ready to accept requests` appears, then query the API:

```bash
$ docker logs -f nominatim
$ curl "http://localhost:8080/search?q=Monaco&format=json"
$ curl "http://localhost:8080/status"
```

The command-line tool runs against the same database:

```bash
$ docker exec nominatim nominatim search --query Monaco --limit 1
```

### Persist the database

The PostgreSQL data directory is `/var/lib/postgresql/17/main`. Mount a volume there so the import survives container
replacement:

```bash
$ docker run -d --name nominatim -p 8080:8080 \
  -e PBF_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf \
  -v nominatim-data:/var/lib/postgresql/17/main \
  dhi.io/nominatim:<tag>
```

### Import a local extract

Mount the extract and point `PBF_PATH` at it:

```bash
$ docker run -d --name nominatim -p 8080:8080 \
  -e PBF_PATH=/nominatim/data/monaco-latest.osm.pbf \
  -v /path/to/osm-maps:/nominatim/data:ro \
  dhi.io/nominatim:<tag>
```

The extract must be readable by UID 65532.

### Environment variables

The image reads the same environment variables as `mediagis/nominatim`. The main ones:

| Variable             | Description                                                                                         | Default        | Required         |
| -------------------- | --------------------------------------------------------------------------------------------------- | -------------- | ---------------- |
| `PBF_URL`            | URL of the OpenStreetMap extract to download and import                                             | none           | One of these two |
| `PBF_PATH`           | Path of an extract inside the container to import                                                   | none           | One of these two |
| `NOMINATIM_PASSWORD` | Password for the `nominatim` and `www-data` database roles; PostgreSQL listens on TCP only when set | none           | No               |
| `THREADS`            | Threads for the import and indexing                                                                 | number of CPUs | No               |
| `GUNICORN_WORKERS`   | API worker processes                                                                                | number of CPUs | No               |
| `IMPORT_STYLE`       | osm2pgsql import style: `admin`, `street`, `address`, `full`, or `extratags`                        | `full`         | No               |
| `REVERSE_ONLY`       | Set to `true` to import data for reverse geocoding only                                             | none           | No               |
| `FREEZE`             | Set to `true` to drop the update tables after the import                                            | none           | No               |
| `REPLICATION_URL`    | Replication source for updates                                                                      | none           | No               |
| `UPDATE_MODE`        | `continuous`, `once`, or `catch-up` when `REPLICATION_URL` is set                                   | none           | No               |
| `WARMUP_ON_STARTUP`  | Set to `true` to warm the database caches before serving                                            | `false`        | No               |
| `POSTGRES_*`         | PostgreSQL tuning, for example `POSTGRES_SHARED_BUFFERS` and `POSTGRES_MAINTENANCE_WORK_MEM`        | `2GB`, `10GB`  | No               |

On a small host, lower the PostgreSQL memory settings:

```bash
$ docker run -d --name nominatim -p 8080:8080 \
  -e PBF_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf \
  -e POSTGRES_SHARED_BUFFERS=256MB \
  -e POSTGRES_MAINTENANCE_WORK_MEM=256MB \
  -e POSTGRES_EFFECTIVE_CACHE_SIZE=1GB \
  dhi.io/nominatim:<tag>
```

### Connect to the database

Set `NOMINATIM_PASSWORD` to open PostgreSQL on port 5432 with password (SCRAM-SHA-256) authentication:

```bash
$ docker run -d --name nominatim -p 8080:8080 -p 5432:5432 \
  -e PBF_URL=https://download.geofabrik.de/europe/monaco-latest.osm.pbf \
  -e NOMINATIM_PASSWORD=<password> \
  dhi.io/nominatim:<tag>
$ psql "host=localhost user=nominatim dbname=nominatim"
```

Inside the container, `psql` connects over the local socket as `nominatim`:

```bash
$ docker exec nominatim psql -d nominatim -c "SELECT count(*) FROM placex"
```

## Non-hardened images vs. Docker Hardened Images

- **PostgreSQL 17 instead of 16.** `mediagis/nominatim` stores data in `/var/lib/postgresql/16/main`. This image runs
  PostgreSQL 17 with data in `/var/lib/postgresql/17/main`. A PostgreSQL 16 data directory cannot be used; import again
  or migrate the database with `pg_dump` and `pg_restore`.
- **Non-root.** PostgreSQL, the import, and the API run as UID 65532 instead of root with `sudo`. A bind-mounted data
  directory or flatnode directory must be writable by UID 65532. The `dev` variants run as root, which PostgreSQL
  refuses; start them with `--user 65532:65532` to run the import and API.
- **No default database password.** `mediagis/nominatim` sets a default `NOMINATIM_PASSWORD` and accepts MD5 logins from
  any address. This image has no default: PostgreSQL listens only on its local socket unless you set
  `NOMINATIM_PASSWORD`, and then it requires SCRAM-SHA-256.
- **Supplementary data from files only.** `IMPORT_WIKIPEDIA`, `IMPORT_SECONDARY_WIKIPEDIA`, `IMPORT_GB_POSTCODES`,
  `IMPORT_US_POSTCODES`, and `IMPORT_TIGER_ADDRESSES` accept a path to a file you mount. The value `true`, which makes
  `mediagis/nominatim` download from a server that project hosts, is rejected. Download the files from the
  [Nominatim import documentation](https://nominatim.org/release-docs/5.3/admin/Import/) instead.
- **Logs.** PostgreSQL and replication output go to the container log rather than to files under `/var/log`.
- **Working directory.** The working directory is the project directory `/nominatim` instead of `/app`, so
  `docker exec <container> nominatim ...` uses the project configuration without `--project-dir`.

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
