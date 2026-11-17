## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Drupal Nginx image

This Docker Hardened Drupal Nginx image includes:

- Nginx, from the same hardened package the Docker Hardened Nginx image uses
- The Brotli, upload progress, and virtual host traffic status dynamic modules, which the presets rely on
- `gotpl`, the template renderer the entrypoint uses to build `/etc/nginx` from environment variables
- The wodby virtual host presets under `/etc/gotpl`: `drupal7` through `drupal11`, `wordpress`, `laravel`, `django`,
  `matomo`, `php`, `html`, and `http-proxy`

## Run the container

The entrypoint renders the Nginx configuration from the `NGINX_*` environment variables and then starts Nginx in the
foreground. Nginx listens on port 8080.

```
$ docker run --rm -d --name drupal-nginx -p 8080:8080 dhi.io/drupal-nginx:<tag>
```

Check the version of Nginx in the image:

```
$ docker run --rm --entrypoint nginx dhi.io/drupal-nginx:<tag> -v
```

### Serve a Drupal site

Point the image at a PHP-FPM container and select the matching Drupal preset. `NGINX_VHOST_PRESET` selects the preset,
`NGINX_BACKEND_HOST` names the PHP-FPM service, and `DRUPAL_SITE` names the site directory under `sites/`. The presets
are version-agnostic and proxy FastCGI to whatever backend you name, so the PHP tag is independent of this image's tag —
choose the version your Drupal release requires. The example pins `8.4-fpm`.

On startup the container creates `sites/<DRUPAL_SITE>` in the document root and symlinks its `files` directory onto
`/mnt/files`, so **the mounted code directory must be writable by uid 65532**, the user this image runs as. Without that
the container exits with `mkdir: cannot create directory ... Permission denied`:

```
$ sudo chown -R 65532:65532 ./drupal
```

For a Drupal 8+ layout whose document root is a `web/` subdirectory, set **both** `NGINX_SERVER_ROOT` (where Nginx
serves from) and `DOCROOT_SUBDIR` (where the site directory is created). Setting only the first puts `sites/` outside
the document root.

```yaml
services:
  nginx:
    image: dhi.io/drupal-nginx:<tag>
    environment:
      NGINX_VHOST_PRESET: drupal11
      NGINX_BACKEND_HOST: php
      NGINX_SERVER_ROOT: /var/www/html/web
      DOCROOT_SUBDIR: web
      DRUPAL_SITE: default
    volumes:
      - ./drupal:/var/www/html
    ports:
      - "8080:8080"
  php:
    image: dhi.io/php:8.4-fpm
    volumes:
      - ./drupal:/var/www/html
```

### Environment variables

The full list of variables is documented upstream at https://github.com/wodby/nginx. The ones that matter most for a
first run are below.

| Variable                | Description                                                                                                                  | Default         | Required                |
| ----------------------- | ---------------------------------------------------------------------------------------------------------------------------- | --------------- | ----------------------- |
| `NGINX_VHOST_PRESET`    | Virtual host preset to render: `drupal7`–`drupal11`, `wordpress`, `laravel`, `django`, `matomo`, `php`, `html`, `http-proxy` | `html`          | No                      |
| `NGINX_BACKEND_HOST`    | Hostname of the PHP-FPM or HTTP backend the preset proxies to                                                                | `php`           | No                      |
| `NGINX_SERVER_ROOT`     | Document root Nginx serves from                                                                                              | `/var/www/html` | No                      |
| `NGINX_SERVER_PORT`     | Port Nginx listens on                                                                                                        | `8080`          | No                      |
| `DOCROOT_SUBDIR`        | Subdirectory of the code mount that is the document root (`web` for Drupal 8+); where `sites/` is created                    | none            | No                      |
| `DRUPAL_SITE`           | Site directory under `sites/`; required by the Drupal presets                                                                | none            | Yes, for Drupal presets |
| `NGINX_METRICS_ENABLED` | Enables the virtual host traffic status zone and its status endpoint                                                         | unset           | No                      |

### Serve static content

With the default `html` preset the image serves whatever is mounted at `/var/www/html`.

```
$ docker run --rm -d -p 8080:8080 -v /some/content:/var/www/html:ro dhi.io/drupal-nginx:<tag>
```

## Non-hardened images vs Docker Hardened Images

The hardened image renders the same `NGINX_*` configuration set as `wodby/nginx`, with these differences:

| Feature          | `wodby/nginx`                                            | Docker Hardened Drupal Nginx                                                                        |
| ---------------- | -------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| Port             | 80                                                       | `8080` (`NGINX_SERVER_PORT` default), because the image runs nonroot                                |
| Privileges       | `sudo nginx`, `sudo init_volumes` chowns on every start  | No `sudo`, never root; directories are created with the runtime user's ownership at build time      |
| Runtime user     | uid 1000                                                 | uid 65532                                                                                           |
| Modules          | Brotli, upload progress and VTS compiled into the binary | Installed as signed dynamic module packages, loaded with `load_module`; preset directives unchanged |
| `user` directive | Always set                                               | Omitted unless `NGINX_USER` is set — an unprivileged master cannot switch users                     |
| Base             | `wodby/alpine`, Nginx compiled from source               | Prebuilt hardened packages; Debian and Alpine variants                                              |

### Document root ownership

Upstream runs as uid 1000 and expects the PHP container to match. This image runs as uid 65532 and creates
`/var/www/html` mode `0770`. It works with any FastCGI backend, but the shared document root must be readable by both
containers, and writable by uid 65532 whenever a preset's startup init creates directories in it.

A bind mount keeps its ownership from the host, so `chown -R 65532:65532` it before starting the Drupal, WordPress or
Laravel presets. An **empty named volume** is instead seeded from the image directory and inherits `0770 65532:65532`,
which a backend running as a different user cannot traverse — PHP-FPM reports that as a bare `File not found.` To pair
with a backend that does not run as 65532, use a host mount whose permissions suit both, or populate the volume from the
application container so it carries that container's ownership.

## Unknown virtual host preset

If `NGINX_VHOST_PRESET` names a preset that does not exist, Nginx fails to start with:

```
nginx: [emerg] open() "/etc/nginx/preset.conf" failed (2: No such file or directory) in /etc/nginx/conf.d/vhost.conf:8
```

The rendered virtual host includes `preset.conf` whenever a preset is named, and the entrypoint only writes that file
when a matching template exists under `/etc/gotpl/presets`. Check the preset name against the list in
[What's included](#whats-included-in-this-drupal-nginx-image). The same message appears when you intend to supply your
own preset and have not mounted a `/etc/nginx/preset.conf` or `/etc/gotpl/presets/<name>.conf.tmpl`.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or package manager unless required for the application to run
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

**Runtime requirements specific to FIPS:**

The FIPS variants serve TLS through the FIPS-validated OpenSSL provider. Cipher suites and digests outside the validated
set are rejected, so TLS configuration supplied through `NGINX_SERVER_EXTRA_CONF_FILEPATH` must stay within FIPS 140
approved algorithms.

## Migrate to a Docker Hardened Image

The hardened image renders the same `NGINX_*` configuration set as `wodby/nginx`, so your existing environment variables
and presets carry over. Account for the differences listed above before switching: Nginx listens on `8080` rather than
`80`, the container runs as uid 65532 instead of 1000, and there is no `sudo`.

### Migration steps

1. Update your image reference. Replace the image reference in your Docker run command or Compose file:
   - From: `wodby/nginx:1.30`
   - To: `dhi.io/drupal-nginx:1.30-alpine3.24` to stay on Alpine, or `dhi.io/drupal-nginx:1.30` for the Debian build.
     Upstream tags such as `1.30` are Alpine-based, while the unqualified hardened tags are Debian, so copying the tag
     across changes your base distro.
1. Update any necessary configuration. If you have custom configurations that rely on features not present in the
   hardened image (like running as root, exposing port 80, or using a shell), you will need to adjust them.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell unless it's required for the application to run, and
typically don't include debugging tools. The recommended method for debugging applications built with Docker Hardened
Images is to use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers.
Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

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

By default, image variants intended for runtime don't contain a shell unless it's required for the application to run.
Use `dev` images in build stages to run shell commands and then copy any necessary artifacts into the runtime stage. For
Alpine-based images, you can use `apk` to install packages; for Debian-based images, use `apt-get`. In addition, use
Docker Debug to debug containers with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
