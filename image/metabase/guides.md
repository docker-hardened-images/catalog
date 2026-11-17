## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a metabase instance

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run --rm -p 127.0.0.1:3000:3000 dhi.io/metabase:<tag>
```

Open `http://localhost:3000` in your browser to reach the setup wizard. The first boot takes a minute or more while
Metabase runs its application database migrations, so wait for the container logs to settle before loading the page.

The example publishes the port on loopback only. Until the setup wizard is completed, whoever reaches the port first
claims the admin account, so widen the binding to `-p 3000:3000` only once setup is finished and the instance sits
behind your own network controls.

By default Metabase stores its application data in an embedded H2 database inside the container. Without a mounted
volume or an external database, this data is lost when the container is removed. See the following use cases for
persisting data.

## Common metabase use cases

### Persist the embedded H2 database

The image stores the embedded H2 database in the `/metabase.db` directory (`MB_DB_FILE=/metabase.db/metabase.db`), the
same location the upstream image uses after its first-boot migration. Mount a volume there so the database survives
container restarts and recreation:

```bash
docker run -d \
  --name metabase \
  -p 127.0.0.1:3000:3000 \
  -v mb-data:/metabase.db \
  dhi.io/metabase:<tag>
```

To store the database somewhere else, set `MB_DB_FILE` to a path on a writable mounted volume.

### Production deployment with PostgreSQL

For production use, point Metabase at an external PostgreSQL or MySQL application database instead of the embedded H2
database. The following `compose.yml` example starts Metabase alongside a PostgreSQL application database:

```yaml
services:
  postgres:
    image: dhi.io/postgres:<tag>
    environment:
      - POSTGRES_DB=metabase
      - POSTGRES_USER=metabase
      - POSTGRES_PASSWORD=metabasepass
    volumes:
      - postgres_data:/var/lib/postgresql/data

  metabase:
    image: dhi.io/metabase:<tag>
    ports:
      - "127.0.0.1:3000:3000"
    environment:
      - MB_DB_TYPE=postgres
      - MB_DB_DBNAME=metabase
      - MB_DB_PORT=5432
      - MB_DB_USER=metabase
      - MB_DB_PASS=metabasepass
      - MB_DB_HOST=postgres
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 15s
      timeout: 5s
      retries: 20
    depends_on:
      - postgres

volumes:
  postgres_data:
```

### Pass database credentials with Docker secrets

Swap any `MB_DB_*` credential variable above for its `_FILE` form (for example
`MB_DB_PASS_FILE=/run/secrets/mb_db_pass`) and the entrypoint reads the value from the file instead of the environment,
so Docker secrets work without running as root. See the
[Metabase environment variable reference](https://www.metabase.com/docs/latest/configuring-metabase/environment-variables)
for the full list.

### Install a third-party database driver

Metabase loads driver jars it finds in `/plugins` at startup. The drivers it ships with are loaded from inside the
uberjar, so `/plugins` holds only the extracted sample database until you add something.

Create the host directory, copy the driver jar (for example, a ClickHouse or Snowflake driver) into it, and make it
writable by the container's user. Metabase also extracts its sample database into `/plugins`, so the mount has to be
writable:

```bash
mkdir -p drivers
cp /path/to/driver.jar drivers/
chown 2000:2000 drivers
```

Then mount it to `/plugins`:

```bash
docker run -d \
  --name metabase \
  -p 127.0.0.1:3000:3000 \
  -v "$(pwd)/drivers:/plugins" \
  dhi.io/metabase:<tag>
```

### Advanced configuration

For single sign-on (SAML, JWT, LDAP), static and interactive embedding, serialization for moving dashboards and
questions between environments, and migrating from the embedded H2 database to PostgreSQL or MySQL with `load-from-h2`,
see the [Metabase documentation](https://www.metabase.com/docs/latest/).

## Non-hardened images vs. Docker Hardened Images

The DHI metabase runtime variants always run as the nonroot `metabase` user on uid/gid 2000, the same ids upstream's
`run_metabase.sh` creates on first boot. An existing H2 or `/plugins` volume written by the upstream image therefore
works here as-is, with no `chown` step. Note that upstream reaches those ids by starting as root and self-dropping,
chowning application paths on the way; the DHI runtime variants never run as root, so that bootstrap branch never
executes and a volume owned by any other uid has to be made writable by uid/gid 2000 before you mount it. Because the
account is baked into the image, upstream's `MUID` and `MGID` variables have no effect.

The hardened system package installs the entrypoint script at `/usr/bin/run_metabase.sh` and the jar at
`/usr/share/metabase/metabase.jar`, and the image keeps upstream's `/app/run_metabase.sh` and `/app/metabase.jar` as
symlinks onto them, so the entrypoint and the `/app`-based layout stay where a migrating user expects them.
`/opt/java/openjdk` also stays as a symlink to the JDK so commands written against upstream's layout keep working.
`MB_DB_FILE` defaults to `/metabase.db/metabase.db` — the same directory layout upstream's first-boot migration produces
— and `/metabase.db` ships writable by the `metabase` user.

The dev variants run as root and do take upstream's bootstrap branch, so they set `MB_DB_FILE=/metabase.db` and let the
script derive that same layout. Run the dev variants as root; running one as a nonroot user needs an explicit
`MB_DB_FILE=/metabase.db/metabase.db`.

The runtime variants keep `bash`, the core utilities the entrypoint script invokes, and `curl` for the
upstream-documented health check (see Image variants below), but contain no package manager.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  **`metabase` is an exception:** its entrypoint `run_metabase.sh` is a shell script, so the runtime variants include
  `bash` and the core utilities it invokes, plus `curl` for the upstream-documented health check. They still run as the
  nonroot user and contain no package manager.

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| :----------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                                                                                                                                        |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                                                                                                                                      |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                                                                                                                                       |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                                                                                                                                       |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                                                                                                                                               |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container.                                                                                                                     |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                                                                                                                                      |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. **`metabase` is an exception:** the upstream entrypoint `run_metabase.sh` is a shell script, so the runtime variants ship `bash` — which also backs `/bin/sh` — plus `coreutils` for the `id` the script calls, and `curl` for the upstream-documented health check. |

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
with no shell. **`metabase` is an exception:** its entrypoint is a shell script, so the runtime variants keep a shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
