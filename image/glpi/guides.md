## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a GLPI image

[GLPI](https://glpi-project.org) is an IT service management and asset inventory web application. Configuration beyond
this quick start is in the [GLPI documentation](https://glpi-project.org/documentation/). This image is the Docker
Hardened Image for the application published as `glpi/glpi`, built from
[glpi-project/docker-images](https://github.com/glpi-project/docker-images).

Lines 12 and 11 are published for Debian 13 and Alpine 3.24. Debian images carry the short tags, such as `12` and `11`.
Alpine images add `alpine` to the tag, such as `12-alpine`.

The entrypoint is upstream's `/opt/glpi/entrypoint.sh`. It creates the directories under `/var/glpi`, forwards GLPI's
log files to the container output, waits for the database, and installs or updates the GLPI database. The default
command is `/opt/glpi/start.sh`, which runs PHP-FPM, nginx on port 80, and the GLPI cron worker. The process runs as
user `nonroot` (uid 65532, gid 65532). The image does not include a database server.

### Run GLPI with MariaDB

Save this as `compose.yaml`:

```yaml
services:
  mariadb:
    image: mariadb:11
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: example-root
      MARIADB_DATABASE: glpi
      MARIADB_USER: glpi
      MARIADB_PASSWORD: example-db
    volumes:
      - mariadb-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 5s
      timeout: 5s
      retries: 30
      start_period: 20s

  glpi:
    image: dhi.io/glpi:<tag>
    restart: unless-stopped
    depends_on:
      mariadb:
        condition: service_healthy
    ports:
      - "8080:80"
    environment:
      GLPI_DB_HOST: mariadb
      GLPI_DB_PORT: "3306"
      GLPI_DB_NAME: glpi
      GLPI_DB_USER: glpi
      GLPI_DB_PASSWORD: example-db
    volumes:
      - glpi-data:/var/glpi

volumes:
  mariadb-data:
  glpi-data:
```

From the directory that contains `compose.yaml`:

```bash
docker compose up -d
```

On first start the entrypoint installs the database. When `docker compose logs glpi` shows the GLPI greeting, open
http://localhost:8080 and sign in as `glpi` with password `glpi`. The installation also creates the default accounts
`tech`, `normal`, and `post-only`. Change the passwords of all four accounts, or disable the ones you do not use, after
the first sign-in. On later starts the entrypoint runs the database update instead.

If any of PHP-FPM, nginx, or the cron worker exits, the container exits with a non-zero status and is not restarted from
inside. Keep a restart policy such as `restart: unless-stopped`.

### Environment variables

| Variable                                                                                            | Description                                                                                                                        | Default | Required                   |
| --------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ------- | -------------------------- |
| `GLPI_DB_HOST`, `GLPI_DB_PORT`, `GLPI_DB_NAME`, `GLPI_DB_USER`, `GLPI_DB_PASSWORD`                  | Database connection. When any of the five is unset, automatic install and update are turned off and GLPI serves its web installer. | none    | Yes, for automatic install |
| `GLPI_DB_SSL`                                                                                       | Set to `true` to connect to the database over TLS.                                                                                 | `false` | No                         |
| `GLPI_DB_SSL_CA`, `GLPI_DB_SSL_CERT`, `GLPI_DB_SSL_KEY`, `GLPI_DB_SSL_CAPATH`, `GLPI_DB_SSL_CIPHER` | Certificate, key, and cipher settings used when `GLPI_DB_SSL` is `true`.                                                           | none    | No                         |
| `GLPI_SKIP_AUTOINSTALL`                                                                             | Set to `true` to skip the database installation on first start.                                                                    | `false` | No                         |
| `GLPI_SKIP_AUTOUPDATE`                                                                              | Set to `true` to skip the database update on later starts.                                                                         | `false` | No                         |
| `GLPI_CRONTAB_ENABLED`                                                                              | Set to `0` to turn off the cron worker, for example on web nodes when another container runs GLPI's scheduled tasks.               | `1`     | No                         |

`GLPI_CONFIG_DIR`, `GLPI_VAR_DIR`, `GLPI_MARKETPLACE_DIR`, and `GLPI_LOG_DIR` are set to `/var/glpi/config`,
`/var/glpi/files`, `/var/glpi/marketplace`, and `/var/glpi/logs`, as in the upstream image.

## Common GLPI use cases

### Persist data

Mount a volume at `/var/glpi`, as in the Compose file above. Without one, the configuration, uploaded documents,
marketplace plugins, and logs are lost when the container is removed. `/var/glpi/config` holds `config_db.php` and
`glpicrypt.key`. GLPI encrypts stored secrets with `glpicrypt.key`, so back it up with the database.

The image has no MySQL or MariaDB client. Dump the database from the database container:

```bash
docker compose exec -T mariadb mariadb-dump -u glpi -pexample-db glpi > glpi.sql
```

### Custom PHP configuration

PHP reads extra `.ini` files from `/etc/php-8.5/conf.d/`. GLPI's own settings are in `/etc/php-8.5/conf.d/000-glpi.ini`,
so name your file so that it sorts after that one. Create `custom-php.ini`:

```ini
memory_limit = 512M
```

Add the file to the `glpi` service in `compose.yaml`:

```yaml
    volumes:
      - glpi-data:/var/glpi
      - ./custom-php.ini:/etc/php-8.5/conf.d/zz-custom.ini:ro
```

After `docker compose up -d`, check the value:

```bash
docker compose exec glpi php -r 'echo ini_get("memory_limit"), PHP_EOL;'
```

PHP-FPM reads the same directory, so the setting also applies to web requests.

### Plugins

Install plugins from the GLPI marketplace, which stores them in `/var/glpi/marketplace`, or mount a directory of plugins
at `/var/www/glpi/plugins`:

```yaml
    volumes:
      - glpi-data:/var/glpi
      - ./plugins:/var/www/glpi/plugins:ro
```

### Scheduled tasks and extra jobs

The cron worker runs GLPI's automatic actions every 60 seconds. To run another command on a schedule, run
`/opt/glpi/scheduler.sh` in a second container from the same image. Add this service to `compose.yaml` to synchronize
LDAP users every six hours:

```yaml
  ldap-sync:
    image: dhi.io/glpi:<tag>
    restart: unless-stopped
    depends_on:
      - glpi
    entrypoint: ["/opt/glpi/scheduler.sh"]
    command: ["--interval", "21600", "--name", "LDAP Sync", "--", "php", "bin/console", "ldap:synchronize_users"]
    environment:
      GLPI_DB_HOST: mariadb
      GLPI_DB_PORT: "3306"
      GLPI_DB_NAME: glpi
      GLPI_DB_USER: glpi
      GLPI_DB_PASSWORD: example-db
    volumes:
      - glpi-data:/var/glpi
```

`--interval` runs the command at start and then every N seconds. `--daily HH:MM` runs it once a day. The scheduler waits
for the database when the `GLPI_DB_*` variables are set. Its container needs the same `/var/glpi` volume, because GLPI
reads its database settings from `/var/glpi/config`.

### Port 80 and capabilities

nginx listens on port 80 inside the container. User 65532 binds that port through the `cap_net_bind_service` file
capability on `/usr/sbin/nginx`, as upstream's Apache does. If you drop all capabilities, add `NET_BIND_SERVICE` back,
for example `--cap-drop ALL --cap-add NET_BIND_SERVICE`, or `capabilities.add: ["NET_BIND_SERVICE"]` in a Kubernetes
security context. Without it, nginx cannot start and the container exits.

### FIPS variants

FIPS variants are published for both lines on Debian 13 and Alpine 3.24, with tags such as `12-fips`, `12-fips-dev`, and
`12-alpine-fips`. They set `OPENSSL_CONF` to `/usr/lib/ssl/openssl.cnf` and `OPENSSL_MODULES` to the OpenSSL modules
directory, so the OpenSSL FIPS provider is active. PHP's `openssl` and `curl` functions, LDAP over TLS, and nginx use
it, and algorithms that are not approved are refused. For example, MD5 through OpenSSL fails:

```bash
docker run --rm --entrypoint php dhi.io/glpi:12-fips -r 'var_dump(openssl_digest("glpi", "md5"));'
```

The output is `bool(false)`. GLPI encrypts stored secrets with `glpicrypt.key` using libsodium (XChaCha20-Poly1305) and
hashes passwords with PHP's bcrypt. Neither uses OpenSSL, so both are outside the FIPS boundary. The FIPS variants cover
only the cryptography that goes through OpenSSL.

## Non-hardened images vs. Docker Hardened Images

### Migrate from glpi/glpi

The entrypoint scripts, `cron-worker.sh`, `scheduler.sh`, environment variables, working directory (`/var/www/glpi`),
port, and `000-glpi.ini` are the same as upstream. These parts differ:

- **User.** The image runs as uid 65532 instead of `www-data` (uid 33). A `/var/glpi` volume created by `glpi/glpi` is
  owned by uid 33, and the entrypoint stops with
  `ERROR: Directory /var/glpi/config is not writable by current user (UID 65532).` Change the owner once before you
  switch images. Stop the GLPI container, then run this with your volume name in place of `glpi_glpi_data` (the name
  that upstream's `docker-compose.example.yml` creates):

  ```bash
  docker run --rm --user 0:0 --entrypoint chown -v glpi_glpi_data:/var/glpi dhi.io/glpi:<tag> -R 65532:65532 /var/glpi
  ```

  On the next start the entrypoint updates the database and your existing accounts keep working.

- **Web server.** nginx and PHP-FPM replace Apache and mod_php. Files mounted under `/etc/apache2` have no effect. The
  nginx configuration is `/etc/nginx/nginx.conf`, with the document root at `/var/www/glpi/public` and every request
  that is not a file routed to `index.php`, as in GLPI's documented nginx setup. Requests up to 20 MB are accepted, to
  match the PHP upload limit. The PHP-FPM configuration is `/etc/php-8.5/php-fpm.conf`. To change either, mount a
  complete replacement file.

- **PHP configuration directory.** Extra `.ini` files go in `/etc/php-8.5/conf.d/` instead of
  `/usr/local/etc/php/conf.d/`. `PHP_INI_DIR` is not set.

- **No supervisord.** `/opt/glpi/start.sh` replaces supervisord, so `/etc/supervisor/conf.d/*.conf` files are not read.
  Run extra jobs in a separate container with `/opt/glpi/scheduler.sh`, as shown in
  [Scheduled tasks and extra jobs](#scheduled-tasks-and-extra-jobs). A process that exits is not restarted inside the
  container; the container exits and your restart policy starts it again.

- **Stop signal.** The image stops on `SIGTERM`, the default, and exits with status 0. Upstream declares `SIGWINCH`.
  Remove `stop_signal: SIGWINCH` or `--stop-signal SIGWINCH` from your configuration; this image ignores `SIGWINCH`, so
  the stop would wait until the engine kills the container.

- **Persistence.** Mount `/var/glpi` explicitly, as shown in [Persist data](#persist-data). Data does not persist across
  container re-creation without a mount.

- **Tools not included.** The image has no `mysql`/`mariadb` client, ACL tools, supervisord, or Apache. Run database
  commands in the database container.

- **Dev variants.** `-dev` and `-fips-dev` images run as root and add a package manager, `apt` on Debian or `apk` on
  Alpine, and findutils. GLPI does not run as root. With the `GLPI_DB_*` variables set, GLPI's console prints
  `WARNING: running as root is discouraged.` and the entrypoint exits. Without them, `/opt/glpi/start.sh` exits with
  `ERROR: GLPI does not run as root. Start the container with --user 65532:65532.` Run them as uid 65532 to serve GLPI:

  ```bash
  docker run -d --name glpi --user 65532:65532 -p 8080:80 -v glpi-data:/var/glpi dhi.io/glpi:12-dev
  ```

  Use root only to install or debug tools, for example `docker run --rm -it --entrypoint bash dhi.io/glpi:12-dev`.

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
