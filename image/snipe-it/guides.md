## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Snipe-IT image

[Snipe-IT](https://snipeitapp.com) is a web application for IT asset management. Configuration beyond this quick start
is in the [Snipe-IT documentation](https://snipe-it.readme.io/docs). This image is the Docker Hardened Image for the
application published as `snipe/snipe-it`. Source is [grokability/snipe-it](https://github.com/grokability/snipe-it).

The image serves HTTP with nginx and PHP-FPM. The application files are at `/usr/share/snipe-it`. `/var/www/html` is a
symlink to that directory, and the working directory is `/var/www/html`. Artisan is `/usr/share/snipe-it/artisan` (the
same file as `/var/www/html/artisan`).

There is no entrypoint. The default command is `/startup.sh`. A command you pass to `docker run` replaces `/startup.sh`.
The runtime process runs as user `snipeit` (uid 10000, gid 10000). Dev variants run as root and still contain the
`snipeit` user.

### Generate an application key

```bash
docker run --rm dhi.io/snipe-it:<tag> php /var/www/html/artisan key:generate --show
```

That command runs `php`, because nothing wraps extra arguments in `/startup.sh`.

`/startup.sh` reads `APP_KEY` from the environment. When `APP_KEY` is unset, it prints an example from
`artisan key:generate --show` and exits 0. Set `APP_KEY` to a generated value before you start the server. The image
`.env` already sets `APP_ENV=production` and `APP_DEBUG=false`.

### Run Snipe-IT with MariaDB

This image does not run MySQL or MariaDB. `mysqldump` is installed at `/usr/bin/mysqldump`, and `DB_DUMP_PATH` in the
image `.env` is `/usr/bin`.

`DB_CONNECTION` in the image `.env` is `mysql`. `DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, and `DB_PASSWORD` in
that file are Docker-link placeholders (`MYSQL_PORT_3306_TCP_ADDR` and similar). Set those five variables in the
container environment. Use `DB_PORT=3306` for MySQL or MariaDB. Also set `APP_URL` to the URL browsers will use.

`/var/lib/snipeit` (mode 0770, uid 10000, gid 10000) holds uploads, private uploads, database dumps, keys, and TLS
files. `/usr/share/snipe-it/storage` (including `framework/sessions`, `framework/cache`, `framework/views`, `logs`, and
`app`) and `/usr/share/snipe-it/bootstrap/cache` are writable by uid 10000. These paths are symlinks into
`/var/lib/snipeit`:

- `/usr/share/snipe-it/public/uploads` → `/var/lib/snipeit/data/uploads`
- `/usr/share/snipe-it/storage/private_uploads` → `/var/lib/snipeit/data/private_uploads`
- `/usr/share/snipe-it/storage/app/backups` → `/var/lib/snipeit/dumps`
- `/usr/share/snipe-it/storage/oauth-private.key` and `oauth-public.key` → `/var/lib/snipeit/keys/`
- `/usr/share/snipe-it/storage/ldap_client_tls.cert` and `ldap_client_tls.key` → `/var/lib/snipeit/keys/`

Save this as `compose.yaml`:

```yaml
services:
  mariadb:
    image: mariadb:11
    environment:
      MARIADB_ROOT_PASSWORD: example-root
      MARIADB_DATABASE: snipeit
      MARIADB_USER: snipeit
      MARIADB_PASSWORD: example-db
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 5s
      timeout: 5s
      retries: 30
      start_period: 20s

  snipeit:
    image: dhi.io/snipe-it:<tag>
    depends_on:
      mariadb:
        condition: service_healthy
    ports:
      - "8080:80"
    environment:
      APP_URL: http://localhost:8080
      APP_KEY: ${APP_KEY}
      DB_HOST: mariadb
      DB_PORT: "3306"
      DB_DATABASE: snipeit
      DB_USERNAME: snipeit
      DB_PASSWORD: example-db
    volumes:
      - snipeit-data:/var/lib/snipeit

volumes:
  snipeit-data:
```

From the directory that contains `compose.yaml`:

```bash
export APP_KEY="$(docker run --rm dhi.io/snipe-it:<tag> php /var/www/html/artisan key:generate --show)"
docker compose up -d
```

`/startup.sh` migrates the database, then starts PHP-FPM and nginx. nginx listens on port 80 inside the container. Open
http://localhost:8080/setup and create the first user.

`/startup.sh` also accepts `APP_KEY_FILE`, `DB_HOST_FILE`, `DB_PORT_FILE`, `DB_DATABASE_FILE`, `DB_USERNAME_FILE`,
`DB_PASSWORD_FILE`, `REDIS_HOST_FILE`, `REDIS_PASSWORD_FILE`, `REDIS_PORT_FILE`, `MAIL_HOST_FILE`, `MAIL_PORT_FILE`,
`MAIL_USERNAME_FILE`, and `MAIL_PASSWORD_FILE`. Each file replaces the variable of the same name without `_FILE`. If
both forms are set, `/startup.sh` exits with an error.

### HTTPS

nginx listens on port 443 only when both `/var/lib/snipeit/ssl/snipeit-ssl.crt` and
`/var/lib/snipeit/ssl/snipeit-ssl.key` exist. Those paths are on the `/var/lib/snipeit` volume. Without the pair,
`/startup.sh` listens on port 80 only.

### Upload size and request headers

`PHP_UPLOAD_LIMIT` is a size in megabytes. When it is set, `/startup.sh` writes that value as `upload_max_filesize` and
`post_max_size` in `/etc/php-8.3/conf.d/zz-upload-limit.ini`. The image file starts at `upload_max_filesize = 2M` and
`post_max_size = 8M`.

`APACHE_LIMIT_REQUEST_FIELD_SIZE` and `APACHE_LIMIT_REQUEST_FIELDS` are written as nginx `large_client_header_buffers`
in `/etc/nginx/snipeit/limits.conf`. If only one of them is set, the field size defaults to `8k` and the field count
defaults to `4`. `APACHE_LIMIT_REQUEST_LINE` is written as nginx `client_header_buffer_size` in the same file.

### Scheduler and programs that are not in this image

`/startup.sh` runs `php artisan schedule:run`, sleeps 60 seconds, and repeats. That loop is the scheduler.

The runtime image includes `bash`, because `/startup.sh` is a bash script. It does not include Composer, git, vim, gcc,
`upgrade.php`, or a MariaDB server.

### Ports on Kubernetes and older engines

`/usr/sbin/nginx` has `cap_net_bind_service`, so uid 10000 can bind ports 80 and 443 when the engine keeps file
capabilities. Kubernetes, and Docker Engine versions older than 20.10, drop file capabilities, so this user cannot bind
those ports there. Add `NET_BIND_SERVICE` to the container security context, and set `runAsUser`, `runAsGroup`, and
`fsGroup` to 10000. nginx still listens on 80, and on 443 when the certificate files above are present.

### FIPS variants

FIPS variants are published for Debian 13 and Alpine 3.24. Tags include `8-fips` and `8-fips-dev`. Those images set
`OPENSSL_CONF` to `/usr/lib/ssl/openssl.cnf`, `OPENSSL_MODULES` to `/usr/lib/x86_64-linux-gnu/ossl-modules` on amd64 and
`/usr/lib/aarch64-linux-gnu/ossl-modules` on arm64, and `SSL_CERT_FILE` to `/etc/ssl/certs/ca-certificates.crt`. They
use the OpenSSL FIPS provider.

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
