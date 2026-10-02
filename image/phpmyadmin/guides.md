## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this phpmyadmin image

This Docker Hardened phpMyAdmin image ships the [phpMyAdmin](https://www.phpmyadmin.net/) web application as a PHP-FPM
service.

- the phpMyAdmin application at `/var/www/html`, installed from the `dhi-phpmyadmin` Debian package built from the
  GPG-verified upstream release
- the Docker Hardened PHP runtime with FPM and the extensions phpMyAdmin uses: `mysqli`, `gd`, `zip`, `bz2`, `bcmath`,
  `opcache`, and `uploadprogress`
- the configuration directory at `/etc/phpmyadmin` with the standard environment-driven `config.inc.php`

The image serves FastCGI on port `9000/tcp` and requires a web server in front of it. There is no Apache variant: the
catalog's hardened PHP stack ships PHP-FPM and CLI packages with no Apache mod_php, so deployments using the upstream
image's default Apache variant must move to a web server plus FastCGI layout.

### Run phpMyAdmin with nginx and MySQL

PHP-FPM serves FastCGI, not HTTP, so phpMyAdmin runs behind a web server that shares its document root. The example
below publishes the phpMyAdmin files to the web server through a shared volume:

```yaml
services:
  mysql:
    image: dhi.io/mysql:8.4
    command: [mysqld]
    environment:
      MYSQL_ROOT_PASSWORD: <root-password>

  phpmyadmin:
    image: dhi.io/phpmyadmin:<tag>
    environment:
      PMA_HOST: mysql
    volumes:
      - document-root:/var/www/html

  nginx:
    image: dhi.io/nginx:1
    ports:
      - "8080:8080"
    volumes:
      - document-root:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro

volumes:
  document-root:
```

The nginx configuration listens on an unprivileged port and forwards PHP requests to the FPM service:

```nginx
server {
    listen 8080;
    root /var/www/html;
    index index.php;

    location ~ /\. {
        deny all;
    }

    location ~* ^/(composer\.(json|lock)|ChangeLog|LICENSE|README(\.md)?)$ {
        deny all;
    }

    location ^~ /vendor/ {
        deny all;
    }

    location ^~ /libraries/ {
        deny all;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_pass phpmyadmin:9000;
        fastcgi_index index.php;
    }
}
```

Open http://localhost:8080 and sign in with your MySQL credentials.

The named `document-root` volume is populated from the image once, on first start, and shadows the packaged application
directory. After pulling a newer image tag, remove the volume (`docker compose down --volumes`); otherwise the container
keeps serving the old files while its package database and SBOM report the new version.
`docker run --rm <image> dpkg -V dhi-phpmyadmin` verifies the served payload matches the package.

### Configuration

phpMyAdmin reads its configuration from environment variables through `/etc/phpmyadmin/config.inc.php`, matching the
upstream image's contract. The most common variables:

| Variable                    | Description                                                                |
| --------------------------- | -------------------------------------------------------------------------- |
| `PMA_HOST`                  | Hostname of the MySQL or MariaDB server                                    |
| `PMA_PORT`                  | Port of the database server                                                |
| `PMA_USER` / `PMA_PASSWORD` | Switch from cookie sign-in to config authentication with fixed credentials |
| `PMA_ARBITRARY`             | Set to `1` to allow connecting to any server from the sign-in page         |
| `PMA_ABSOLUTE_URI`          | Full URL when running behind a reverse proxy                               |
| `PMA_CONFIG_BASE64`         | Replace `config.inc.php` with a base64-encoded file                        |
| `PMA_USER_CONFIG_BASE64`    | Provide a base64-encoded `config.user.inc.php`                             |
| `MAX_EXECUTION_TIME`        | PHP `max_execution_time`, default `600`                                    |
| `MEMORY_LIMIT`              | PHP `memory_limit`, default `512M`                                         |
| `UPLOAD_LIMIT`              | PHP `upload_max_filesize` and `post_max_size`, default `2048K`             |
| `TZ`                        | PHP `date.timezone`, default `UTC`                                         |
| `SESSION_SAVE_PATH`         | PHP session directory, default `/sessions`                                 |
| `HIDE_PHP_VERSION`          | Ignored by this image: `expose_php = Off` is always set                    |

This table is a getting-started subset; the full list of supported variables is documented in the
[upstream image's README](https://github.com/phpmyadmin/docker#readme).

Variables holding credentials, plus `PMA_HOST`, `PMA_HOSTS`, and `PMA_CONTROLHOST`, also accept the `_FILE` suffix to
read the value from a mounted secrets file. `MYSQL_ROOT_PASSWORD` and `MYSQL_PASSWORD` are resolved the same way.

The session encryption secret (`blowfish_secret`) is generated at first start and stored at
`/etc/phpmyadmin/config.secret.inc.php`. Sign-in sessions survive container restarts only if `/etc/phpmyadmin` is a
persistent volume or the secret is provided through `PMA_CONFIG_BASE64`. When running more than one replica behind a
load balancer, provide the same secret to every replica through `PMA_CONFIG_BASE64` or a shared `/etc/phpmyadmin`
volume; otherwise each replica generates its own secret and cookie sign-in breaks across replicas. When
`PMA_CONFIG_BASE64` is set, the entrypoint skips secret generation and the provided configuration must define
`$cfg['blowfish_secret']` itself.

To run with a read-only root filesystem, mount tmpfs filesystems owned by the nonroot user (uid 65532) over the writable
paths, and provide the session secret yourself through a read-only mount:

```console
docker run --read-only \
  --tmpfs /sessions:uid=65532,gid=65532,mode=0700 \
  --tmpfs /var/lib/phpmyadmin/tmp:uid=65532,gid=65532,mode=0700 \
  -v ./config.secret.inc.php:/etc/phpmyadmin/config.secret.inc.php:ro \
  -e PMA_HOST=mysql dhi.io/phpmyadmin:<tag>
```

Alternatively, mount a tmpfs with the same ownership options at `/etc/phpmyadmin` and supply the full configuration
through `PMA_CONFIG_BASE64`. The explicit `uid`/`gid` options matter: plain `docker run` and Kubernetes `emptyDir`
volumes mount tmpfs root-owned by default (use `fsGroup` in Kubernetes), while Docker Compose applies the image's
directory ownership automatically.

### Ports

| Port   | Description               |
| ------ | ------------------------- |
| `9000` | PHP-FPM FastCGI interface |

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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations.

In this image, the validated OpenSSL provider covers PHP's `openssl` extension paths, such as TLS connections to the
database. phpMyAdmin encrypts its authentication cookies with libsodium (`sodium_crypto_secretbox`), which is not part
of the FIPS module.

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
