## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start Directus with SQLite

The image defaults to a SQLite database at `/directus/database/database.sqlite`. Mount the database, uploads and
extensions directories so the data survives the container, set a `SECRET` of at least 32 characters, and give the first
admin user an email and a password. The container runs as uid 1000, the same as the upstream image, so host directories
you bind mount need to be writable by that uid.

```
mkdir -p database uploads extensions
sudo chown -R 1000:1000 database uploads extensions

docker run -d --name directus -p 127.0.0.1:8055:8055 \
  -e SECRET=replace-with-a-random-string-of-32-characters-or-more \
  -e ADMIN_EMAIL=admin@example.com \
  -e ADMIN_PASSWORD=replace-with-a-password \
  -v "$PWD/database:/directus/database" \
  -v "$PWD/uploads:/directus/uploads" \
  -v "$PWD/extensions:/directus/extensions" \
  dhi.io/directus:<tag>
```

Replace `<tag>` with the version you want to run. The first start creates the system tables and the admin user. The
Studio is then available at `http://127.0.0.1:8055/admin` and the API answers at `http://127.0.0.1:8055`.

```
curl http://127.0.0.1:8055/server/ping
```

`/server/ping` answers `pong` as soon as the HTTP server is up and needs no authentication, so it works as a liveness
probe. `/server/health` reports the status of the API and its dependencies but answers `403` to anonymous requests, so
call it with a token, for example a static token set with `ADMIN_TOKEN`.

### Run with PostgreSQL

Most production deployments keep the data in PostgreSQL. This compose file follows the upstream deployment guide with
the image reference changed and the port bound to loopback.

```yaml
services:
  database:
    image: dhi.io/postgres:17
    environment:
      POSTGRES_USER: directus
      POSTGRES_PASSWORD: replace-with-a-database-password
      POSTGRES_DB: directus
    volumes:
      - postgres-data:/var/lib/postgresql/data

  directus:
    image: dhi.io/directus:<tag>
    ports:
      - "127.0.0.1:8055:8055"
    volumes:
      - ./uploads:/directus/uploads
      - ./extensions:/directus/extensions
    depends_on:
      - database
    environment:
      SECRET: replace-with-a-random-string-of-32-characters-or-more
      DB_CLIENT: pg
      DB_HOST: database
      DB_PORT: 5432
      DB_DATABASE: directus
      DB_USER: directus
      DB_PASSWORD: replace-with-a-database-password
      ADMIN_EMAIL: admin@example.com
      ADMIN_PASSWORD: replace-with-a-password
      PUBLIC_URL: http://127.0.0.1:8055

volumes:
  postgres-data:
```

### Run CLI commands

The upstream image runs CLI commands with `npx directus`. This image has no npm or npx, so the `directus` command on
`PATH` takes their place. Run it in the running container with `docker exec`.

```
docker exec directus directus --version
docker exec directus directus schema snapshot --yes /directus/uploads/snapshot.yaml
docker exec directus pm2 list
```

`node cli.js <command>` from the `/directus` working directory works as well, the same as upstream. With `docker run` or
a compose `command:` override, the entrypoint is already `node`, so name the script without it.

```
docker run --rm -e SECRET=replace-with-a-random-string-of-32-characters-or-more \
  -e ADMIN_EMAIL=admin@example.com -e ADMIN_PASSWORD=replace-with-a-password \
  -v "$PWD/database:/directus/database" \
  dhi.io/directus:<tag> cli.js bootstrap
```

### Configuration

Directus reads all of its settings from environment variables. `SECRET` signs the access tokens and must be set to the
same value on every instance. `PUBLIC_URL` is needed for OAuth redirects and links in emails. `DB_CLIENT` picks the
database driver and the `DB_` variables that follow it configure the connection. The full list is in the
[upstream configuration reference](https://directus.com/docs/configuration/general).

Directus sends anonymous usage data upstream by default. Set `TELEMETRY=false` to turn it off. The `directus` CLI also
asks the npm registry for newer versions on every start, container start included. Without network access it gives up
after 8 seconds and continues.

Set `WEBSOCKETS_ENABLED=true` to serve the realtime API on the same port.

The bundled mysql2 driver disables the `mysql_clear_password` authentication plugin by default, so a MySQL server that
needs it, PAM or LDAP authentication for example, fails with `MYSQL_CLEAR_PASSWORD_NOT_ENABLED` until
`DB_ENABLE_CLEARTEXT_PLUGIN=true` is set. Standard `caching_sha2_password` and `mysql_native_password` logins are
unaffected.

## Non-hardened images vs. Docker Hardened Images

The container runs as uid 1000, the `node` user of the upstream image, so volumes created by the upstream image keep
working. The image has no shell, no package manager, no npm, no npx and no corepack. Use `dhi.io/directus:<tag>-dev` or
Docker Debug when you need them.

The application lives in `/usr/lib/nodejs/directus`. `/directus` is a symlink to that directory and stays the working
directory, so `DB_FILENAME`, `EXTENSIONS_PATH`, `STORAGE_LOCAL_ROOT` and volume mounts resolve as they do upstream. The
`database`, `uploads`, `extensions`, `.pm2` and `.temp` directories exist and are writable by uid 1000 before any mount.
Everything else under `/directus` is read-only for the runtime user, where upstream lets the `node` user write the whole
tree.

`TEMP_PATH` is set to `/directus/.temp`. Upstream leaves it at its default, `./node_modules/.directus`, which sits in
the read-only code tree here. Directus writes the app extensions bundle, marketplace downloads and remote extension
copies there, so without the change custom Studio extensions would not load. With a read-only root filesystem, mount
writable storage on `/directus/.pm2` and `/directus/.temp` as well as on the data directories.

The entrypoint is `node` and the default command is `docker-entrypoint.cjs`, the process the upstream entrypoint script
ends up running. A `command:` override written for the upstream image drops its leading `node`, so
`command: ["node", "cli.js", "bootstrap"]` becomes `command: ["cli.js", "bootstrap"]`. `pm2` is on `PATH` at
`/usr/local/bin/pm2` as upstream links it, so `docker exec directus pm2 list` works the same.

The `directus` command on `PATH` replaces `npx directus`.

The FIPS variants run Node.js with the OpenSSL FIPS provider, so TLS and the `crypto` calls Directus and its database
drivers make go through the validated module. Password hashing uses argon2, a native library outside the OpenSSL module,
and keeps working. PostgreSQL `md5` password authentication hashes the password with MD5 and fails on the FIPS variants,
so use `scram-sha-256`, the PostgreSQL default since version 14.

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
