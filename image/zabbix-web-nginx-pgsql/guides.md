## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Zabbix web interface image

This Docker Hardened Zabbix web interface image includes:

- `nginx` — web server that serves the Zabbix frontend on port 8080, and on 8443 when `ssl.crt`, `ssl.key` and
  `dhparam.pem` are mounted in `/etc/ssl/nginx`
- `php-fpm` — FastCGI process manager that runs the Zabbix frontend PHP code
- `psql` — PostgreSQL client the 6.0, 7.0 and 7.4 entrypoints use to wait for the database
- `curl` — HTTP client for the `/ping` health probe

The image runs the same entrypoint as the upstream `zabbix/zabbix-web-nginx-pgsql` image and reads the same environment
variables. See the
[Zabbix documentation](https://www.zabbix.com/documentation/current/en/manual/installation/containers) for the full
list.

## Start a Zabbix web interface

The web interface needs a PostgreSQL database that a Zabbix server has created and seeded. The frontend only accepts a
database schema of its own minor version, so run a Zabbix server of the same minor version as the image tag: a `7.4` web
interface needs a `7.4` server.

The following Compose file starts PostgreSQL, a Zabbix 7.4 server, and the web interface:

```yaml
services:
  postgres:
    image: dhi.io/postgres:17
    environment:
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: zabbix
      POSTGRES_DB: zabbix
    volumes:
      - postgres-data:/var/lib/postgresql

  zabbix-server:
    image: zabbix/zabbix-server-pgsql:alpine-7.4.16
    environment:
      DB_SERVER_HOST: postgres
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: zabbix
      POSTGRES_DB: zabbix
    depends_on:
      - postgres

  zabbix-web:
    image: dhi.io/zabbix-web-nginx-pgsql:7.4
    environment:
      DB_SERVER_HOST: postgres
      POSTGRES_USER: zabbix
      POSTGRES_PASSWORD: zabbix
      POSTGRES_DB: zabbix
      ZBX_SERVER_HOST: zabbix-server
      PHP_TZ: Europe/Berlin
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/ping"]
      interval: 30s
      timeout: 3s
      start_period: 40s
      start_interval: 5s
      retries: 3
    depends_on:
      - zabbix-server

volumes:
  postgres-data:
```

```bash
$ docker compose up -d
```

The Zabbix server creates the database schema on its first start, which takes about a minute. Then open
`http://localhost:8080` and sign in as `Admin` with the password `zabbix`. Change that password after the first sign-in.

### Environment variables

| Variable            | Description                                                              | Default           | Required |
| ------------------- | ------------------------------------------------------------------------ | ----------------- | -------- |
| `DB_SERVER_HOST`    | Host name of the PostgreSQL server                                       | `postgres-server` | No       |
| `DB_SERVER_PORT`    | Port of the PostgreSQL server                                            | `5432`            | No       |
| `POSTGRES_USER`     | Database user. `POSTGRES_USER_FILE` reads it from a file instead         | `zabbix`          | Yes      |
| `POSTGRES_PASSWORD` | Database password. `POSTGRES_PASSWORD_FILE` reads it from a file instead | `zabbix`          | Yes      |
| `POSTGRES_DB`       | Database name                                                            | `zabbix`          | No       |
| `ZBX_SERVER_HOST`   | Host name of the Zabbix server the frontend connects to                  | none              | No       |
| `ZBX_SERVER_NAME`   | Installation name shown in the page title and the header                 | `Zabbix docker`   | No       |
| `PHP_TZ`            | Default time zone of the frontend                                        | `Europe/Riga`     | No       |

Set `POSTGRES_USER` and `POSTGRES_PASSWORD` even when the defaults match your database. On the 6.0, 7.0 and 7.4 tags,
the entrypoint checks the database as the `postgres` user when they are unset, keeps logging
`PostgreSQL server is not available. Waiting 5 seconds...`, and never starts the web server.

## Non-hardened images vs. Docker Hardened Images

### Health check

The upstream image declares a `HEALTHCHECK` that runs `curl -f http://localhost:8080/ping`. This image declares no
health check. It still serves `/ping`, which returns `pong` from PHP-FPM through nginx, and it still contains `curl`, so
you define the check where you run the container. The `healthcheck` in the Compose file above is one example, and
upstream's shell form `curl -f http://localhost:8080/ping || exit 1` also works.

In Kubernetes, use an HTTP probe on the same path. `/ping` answers only after the entrypoint has connected to the
database and started nginx, so give the container a startup probe:

```yaml
containers:
  - name: zabbix-web
    image: dhi.io/zabbix-web-nginx-pgsql:7.4
    ports:
      - containerPort: 8080
    startupProbe:
      httpGet:
        path: /ping
        port: 8080
      periodSeconds: 5
      failureThreshold: 30
    readinessProbe:
      httpGet:
        path: /ping
        port: 8080
      periodSeconds: 10
      timeoutSeconds: 3
    livenessProbe:
      httpGet:
        path: /ping
        port: 8080
      periodSeconds: 30
      timeoutSeconds: 3
```

The image runs as UID 1997, the same as upstream. Its writable directories are owned by `1997:0` with group write
permission, so a platform that assigns an arbitrary UID with group 0 also works.

### Configuration file locations

The entrypoint finds the nginx and PHP-FPM configuration through environment variables that the image sets. The
variables keep their upstream names, but some of the files are at different paths:

| File                  | Upstream Alpine                    | Upstream Ubuntu                       | This image                           | Variable              |
| --------------------- | ---------------------------------- | ------------------------------------- | ------------------------------------ | --------------------- |
| nginx main config     | `/etc/nginx/nginx.conf`            | `/etc/nginx/nginx.conf`               | `/etc/nginx/nginx-zabbix.conf`       | `NGINX_CONF_FILE`     |
| nginx virtual hosts   | `/etc/nginx/http.d`                | `/etc/nginx/conf.d`                   | `/etc/nginx/conf.d`                  | `NGINX_CONFD_DIR`     |
| PHP-FPM binary        | `/usr/sbin/php-fpm85`              | `/usr/sbin/php-fpm8.5`                | `/usr/sbin/php-fpm-8.5`              | `PHP_FPM_BIN`         |
| PHP-FPM main config   | `/etc/php85/php-fpm.conf`          | `/etc/php/8.5/fpm/php-fpm.conf`       | `/etc/php-8.5/php-fpm-zabbix.conf`   | `PHP_FPM_CONFIG`      |
| PHP-FPM `zabbix` pool | `/etc/php85/php-fpm.d/zabbix.conf` | `/etc/php/8.5/fpm/pool.d/zabbix.conf` | `/etc/php-8.5/php-fpm.d/zabbix.conf` | `PHP_ZBX_CONFIG_FILE` |

The 6.0 tags use PHP 8.3, so their PHP-FPM paths contain `8.3` instead of `8.5`.

On the Alpine tags, `/etc/nginx/http.d` is a symlink to `/etc/nginx/conf.d`, so a virtual host file you mount into the
upstream Alpine path still loads.

The entrypoint edits the nginx main config in place at every start, so bind-mounting a single file over
`/etc/nginx/nginx-zabbix.conf` makes the container exit with `sed: cannot rename ... Resource busy`: GNU `sed` on the
Debian tags prints `Device or resource busy`, and busybox `sed` on the Alpine tags prints `Resource busy`. To replace
that file, copy it into a derived image:

```dockerfile
FROM dhi.io/zabbix-web-nginx-pgsql:7.4
COPY --chown=1997:0 nginx-zabbix.conf /etc/nginx/nginx-zabbix.conf
```

### Tags

Upstream's default flavor is Alpine. This image's tags without a distribution suffix are Debian-based. To stay on
Alpine, use the tags that end in `-alpine` or `-alpine3.24`:

| Upstream tag    | Docker Hardened Image tag                       |
| --------------- | ----------------------------------------------- |
| `alpine-7.4.16` | `7.4.16-alpine3.24` or `7.4-alpine`             |
| `ubuntu-7.4.16` | `7.4.16` or `7.4` (Debian 13 instead of Ubuntu) |

This image has no `latest` tag. Pick the tag that matches your Zabbix server's minor version.

### Dev variants

The `dev` tags run as root. When the entrypoint runs as root, it starts the nginx and PHP-FPM workers as the user in
`DAEMON_USER` and `DAEMON_GROUP`. This image sets both to `zabbix` (UID 1997), the owner of the writable directories,
where upstream uses `nginx` on Alpine and `www-data` on Ubuntu.

### FIPS variants

The `fips` tags configure OpenSSL with its FIPS-validated provider, which nginx uses for HTTPS on port 8443 and PHP uses
for its OpenSSL functions. To check that the provider is active:

```bash
$ docker run --rm --entrypoint openssl dhi.io/zabbix-web-nginx-pgsql:7.4-fips list -providers
```

The output lists the `fips` provider (`OpenSSL FIPS Provider`) with `status: active`. Ciphers and certificates you
configure for TLS must use FIPS 140 approved algorithms.

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
