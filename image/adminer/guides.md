## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Adminer image

This Docker Hardened Adminer image provides a complete PHP-FPM environment for running Adminer:

- **Adminer**: compiled from source at the latest release, including the design theme collection and bundled community
  plugins
- **PHP-FPM**: FastCGI Process Manager on port 9000 for high-performance PHP processing (PHP CLI is also present, used
  by the entrypoint to load `ADMINER_PLUGINS`)
- **Database drivers**: `mysqli` and `pdo_pgsql`, `pdo_sqlite`, `pdo_odbc`, `pdo_dblib` covering MySQL/MariaDB,
  PostgreSQL, SQLite, generic ODBC, and MS SQL/Sybase
- **Security hardening**: runs as nonroot user (uid/gid 65532), minimal attack surface
- **Tuned PHP configuration**: raised upload size, memory, and execution time limits so SQL dump import/export work at
  realistic file sizes

Unlike some database tools, Adminer does not read database connection details from environment variables. You connect to
a database directly from Adminer's login form (driver, server, username, password) after the container starts.

Note: PHP-FPM runs on port 9000 and requires a web server (nginx, Apache, Caddy) to handle HTTP requests and proxy to
PHP-FPM.

## Start an Adminer instance

```bash
docker run -d \
  --name adminer \
  -p 9000:9000 \
  dhi.io/adminer:<tag>
```

This starts PHP-FPM on port 9000. You'll need a web server in front of it to serve HTTP requests (see the complete stack
example below). Once running, open Adminer in a browser and log in with the driver, host, and credentials of the
database you want to manage — no connection configuration is required in the container itself.

### Selecting a design or loading plugins

The official environment-variable contract is preserved:

- `ADMINER_DESIGN`: selects one of the bundled UI themes (for example `flat`, `nette`) by symlinking its stylesheet on
  container start
- `ADMINER_PLUGINS`: a space-separated list of bundled plugin names (for example `slugify tables-filter`) to load
  automatically on container start
- `ADMINER_DEFAULT_SERVER`: prefills the "Server" field on the login form

```bash
docker run -d \
  --name adminer \
  -p 9000:9000 \
  -e ADMINER_DESIGN=flat \
  -e ADMINER_DEFAULT_SERVER=db \
  dhi.io/adminer:<tag>
```

## Common Adminer use cases

### Complete stack with nginx and MySQL

```yaml
services:
  db:
    image: dhi.io/mysql:8.4
    command: mysqld
    environment:
      MYSQL_ROOT_PASSWORD: rootsecret
    volumes:
      - db_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "-uroot", "-prootsecret"]
      interval: 2s
      timeout: 3s
      retries: 30

  adminer:
    image: dhi.io/adminer:<tag>
    environment:
      ADMINER_DEFAULT_SERVER: db
    depends_on:
      db:
        condition: service_healthy

  nginx:
    image: dhi.io/nginx:1
    ports:
      - "8080:8080"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - adminer

volumes:
  db_data:
```

`ADMINER_DEFAULT_SERVER` only prefills the login form's Server field — you still log in with real credentials at the
login page, Adminer never auto-authenticates from environment variables.

Example nginx configuration (`nginx.conf`):

**Important**: The DHI nginx image runs as nonroot and requires the PID file directive to use a writable location.

```nginx
pid /tmp/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    server {
        listen 8080;

        # Adminer is a single front controller; nginx has no access to the
        # adminer container's filesystem, so every request (including
        # adminer.css) is dispatched to index.php with the original URI
        # preserved in DOCUMENT_URI.
        location / {
            fastcgi_pass adminer:9000;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME /var/www/html/index.php;
            fastcgi_param DOCUMENT_URI $uri;
        }
    }
}
```

### Adding custom PHP extensions

If you need additional extensions beyond the bundled database drivers (for example redis, mongodb), use a multi-stage
build with `dhi.io/php` as the builder base.

```dockerfile
# Stage 1: Compile extension using dev variant
FROM dhi.io/php:8.5-dev as builder

RUN set -eux; \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        libpcre2-dev && \
    cd /tmp && \
    git clone https://github.com/krakjoe/apcu.git && \
    cd apcu && \
    phpize && \
    ./configure --enable-apcu && \
    make && \
    make install && \
    mkdir -p /extensions && \
    cp $(php-config --extension-dir)/apcu.so /extensions/ && \
    mkdir -p /ext-config && \
    echo "extension=apcu.so" > /ext-config/docker-php-ext-apcu.ini

# Stage 2: Runtime image with extension
FROM dhi.io/adminer:<tag>

ARG PHP_EXT_DIR=/usr/lib/php/extensions/no-debug-non-zts-20250925
ARG PHP_CONF_DIR=/etc/php-8.5/conf.d

COPY --from=builder /extensions/apcu.so "${PHP_EXT_DIR}/"
COPY --from=builder /ext-config/docker-php-ext-apcu.ini "${PHP_CONF_DIR}/"
```

## Docker Official Images vs. Docker Hardened Images

### Key differences

| Feature          | Docker Official Adminer              | Docker Hardened Adminer                             |
| ---------------- | ------------------------------------ | --------------------------------------------------- |
| Security         | Standard base with common utilities  | Minimal, hardened base with security patches        |
| Shell access     | Full shell (bash/sh) available       | `bash` only, required by the entrypoint             |
| Package manager  | apk available                        | No package manager in runtime variants              |
| User             | Runs as `adminer` (non-root already) | Runs as nonroot user (uid/gid 65532)                |
| Attack surface   | Larger due to additional utilities   | Minimal, only essential components                  |
| Debugging        | Traditional shell debugging          | Use Docker Debug or Image Mount for troubleshooting |
| Database drivers | Same drivers                         | Same drivers                                        |
| Deployment mode  | FPM or standalone `php -S` variant   | PHP-FPM only (pair with your web server)            |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

Most hardened images intended for runtime don't contain a shell nor any tools for debugging. This image is an exception:
its entrypoint requires `bash` to set up `ADMINER_DESIGN`/`ADMINER_PLUGINS`, so a minimal shell is present. Common
debugging methods for applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools

For example, you can use Docker Debug:

```bash
docker debug adminer
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:adminer \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/adminer:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run Adminer

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to install additional PHP extensions or customize the environment

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                     |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                   |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user (uid/gid 65532). Ensure that necessary files and directories are accessible to the nonroot user.                    |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                              |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                            |
| Ports              | Non-dev hardened images run as a nonroot user by default. PHP-FPM's default port 9000 is not affected by this limitation and works without any special configuration.                         |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.   |
| Standalone mode    | Docker Hardened Adminer uses PHP-FPM only. If migrating from the official image's standalone (`php -S`) variant, add a web server (nginx, Caddy, or Apache) to proxy to PHP-FPM on port 9000. |
| Environment vars   | `ADMINER_DESIGN`, `ADMINER_PLUGINS`, and `ADMINER_DEFAULT_SERVER` behave the same as the official image.                                                                                      |

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

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

Most hardened images intended for runtime don't contain a shell nor any tools for debugging; this image ships a minimal
`bash` for its entrypoint (see [No shell](#no-shell) below). The recommended method for debugging applications built
with Docker Hardened Images is to use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to
these containers.

```bash
# View PHP-FPM logs
docker logs adminer

# Use Docker Debug for interactive troubleshooting
docker debug adminer
```

### Permissions

By default image variants intended for runtime run as the nonroot user (uid/gid 65532). If you set `ADMINER_DESIGN` or
`ADMINER_PLUGINS`, the entrypoint writes a symlink and generated plugin files directly under `/var/www/html`, which is
already writable by the nonroot user in this image.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. PHP-FPM's default port 9000 is not affected by this limitation
and works without any special configuration. Your web server (nginx, Apache) will bind to ports 80/443, not the Adminer
container.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

The Adminer image uses `/entrypoint.sh` as its entry point, with `php-fpm` as the default command. The entrypoint sets
up `ADMINER_DESIGN`/`ADMINER_PLUGINS` before starting PHP-FPM; if you customize the entry point, ensure it still
performs that setup (or does it yourself) and that PHP-FPM continues to run in the foreground.

### No shell

Most image variants intended for runtime don't contain a shell. This image is an exception: it ships a minimal `bash`,
required by `/entrypoint.sh` to set up `ADMINER_DESIGN`/`ADMINER_PLUGINS` on container start. Use `dev` images in build
stages to run other shell commands and then copy any necessary artifacts into the runtime stage.
