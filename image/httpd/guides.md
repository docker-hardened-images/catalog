## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/httpd:<tag>`
- Mirrored image: `<your-namespace>/dhi-httpd:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this httpd image

This Docker Hardened httpd image includes:

- httpd — Apache HTTP Server daemon
- httpd-foreground — Wrapper script used to run httpd in the foreground inside containers
- apachectl — Control interface for the Apache HTTP Server

## Start a httpd image

### Basic usage

```bash
$ docker run -d --name my-httpd -p 8080:8080 \
  dhi.io/httpd:<tag>
```

This starts the httpd runtime variant and maps the container's HTTP port (8080) to the host.

### With Docker Compose (recommended for complex setups)

```yaml
version: '3.8'
services:
  httpd:
    image: dhi.io/httpd:<tag>
    container_name: my-httpd
    ports:
      - "8080:8080"
    environment:
      - HTTPD_PREFIX=/usr/local/apache2
    volumes:
      - ./website:/usr/local/apache2/htdocs:ro
```

### Environment variables

| Variable        | Description                                                     | Default                    | Required |
| --------------- | --------------------------------------------------------------- | -------------------------- | -------- |
| `HTTPD_VERSION` | The packaged Apache HTTP Server version inside the image        | set by image (e.g. 2.4.66) | No       |
| `HTTPD_PREFIX`  | Installation prefix used by Apache (paths are relative to this) | `/usr/local/apache2`       | No       |

Example with environment variables:

```bash
$ docker run -d --name my-httpd -p 8080:8080 \
  -e HTTPD_PREFIX=/usr/local/apache2 \
  dhi.io/httpd:<tag>
```

## Common httpd use cases

- Basic server: serve static content from a mounted host directory. Example:

  ```bash
  docker run -d -p 8080:8080 \
    -v $(pwd)/website:/usr/local/apache2/htdocs:ro \
    dhi.io/httpd:<tag>
  ```

- Server with custom configuration: mount httpd.conf or extra configuration files into the container. Example:

  ```bash
  docker run -d -p 8080:8080 \
    -v $(pwd)/httpd.conf:/usr/local/apache2/conf/httpd.conf:ro \
    dhi.io/httpd:<tag>
  ```

- Server with TLS/SSL: The default `httpd-ssl.conf` uses `Listen 443`, which won't work with the nonroot user. You must
  provide a custom SSL config that uses a non-privileged port (e.g., 8443). Mount your cert, key, and modified SSL
  config:

  ```bash
  docker run -d -p 8443:8443 \
    -v /path/to/server.crt:/usr/local/apache2/conf/server.crt:ro \
    -v /path/to/server.key:/usr/local/apache2/conf/server.key:ro \
    -v /path/to/httpd-ssl.conf:/usr/local/apache2/conf/extra/httpd-ssl.conf:ro \
    dhi.io/httpd:<tag>
  ```

  Your custom `httpd-ssl.conf` should include `Listen 8443` instead of `Listen 443`.

## Enabling additional modules

This image includes commonly needed modules that are built but not loaded by default. This keeps the default
configuration minimal while allowing you to enable additional functionality as needed.

### Available modules (not loaded by default)

The following modules are built and available at `/usr/local/apache2/modules/`:

| Module         | File                | Purpose                     |
| -------------- | ------------------- | --------------------------- |
| mod_rewrite    | `mod_rewrite.so`    | URL rewriting               |
| mod_ssl        | `mod_ssl.so`        | HTTPS/TLS support           |
| mod_proxy      | `mod_proxy.so`      | Reverse proxy (base module) |
| mod_proxy_http | `mod_proxy_http.so` | HTTP proxy support          |
| mod_deflate    | `mod_deflate.so`    | Gzip compression            |

### How to enable modules

To enable a module, add a `LoadModule` directive to your custom `httpd.conf`:

```apache
# Enable URL rewriting
LoadModule rewrite_module modules/mod_rewrite.so

# Enable gzip compression
LoadModule deflate_module modules/mod_deflate.so

# Enable reverse proxy (requires both modules)
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_http_module modules/mod_proxy_http.so
```

### Example: Enable mod_rewrite for URL rewriting

Create a custom configuration file (`httpd-custom.conf`):

```apache
ServerRoot "/usr/local/apache2"
Listen 8080

# Core modules (required)
LoadModule mpm_event_module modules/mod_mpm_event.so
LoadModule unixd_module modules/mod_unixd.so
LoadModule authz_core_module modules/mod_authz_core.so
LoadModule dir_module modules/mod_dir.so
LoadModule mime_module modules/mod_mime.so
LoadModule log_config_module modules/mod_log_config.so

# Enable rewrite module
LoadModule rewrite_module modules/mod_rewrite.so

User www-data
Group www-data

ServerName localhost
ErrorLog /proc/self/fd/2
CustomLog /proc/self/fd/1 common
LogFormat "%h %l %u %t \"%r\" %>s %b" common

DocumentRoot "/usr/local/apache2/htdocs"
<Directory "/usr/local/apache2/htdocs">
    Options FollowSymLinks
    AllowOverride All
    Require all granted

    # Example rewrite rule
    RewriteEngine On
    RewriteRule ^old-page\.html$ /new-page.html [R=301,L]
</Directory>

DirectoryIndex index.html
TypesConfig conf/mime.types
```

Run with the custom configuration:

```bash
docker run -d -p 8080:8080 \
  -v $(pwd)/httpd-custom.conf:/usr/local/apache2/conf/httpd.conf:ro \
  -v $(pwd)/website:/usr/local/apache2/htdocs:ro \
  dhi.io/httpd:<tag>
```

### Verify modules are loaded

To check which modules are currently loaded:

```bash
docker run --rm --entrypoint httpd dhi.io/httpd:<tag> -M
```

## Troubleshooting

### Check configuration syntax

Test a mounted configuration before starting the container:

```bash
docker run --rm \
  -v $(pwd)/httpd.conf:/usr/local/apache2/conf/httpd.conf:ro \
  --entrypoint httpd \
  dhi.io/httpd:<tag> \
  -t
```

This runs httpd's configuration test and reports syntax errors.

### Debug mode (foreground)

Run Apache in the foreground with verbose/debug logging to the console:

```bash
docker run --rm -p 8080:8080 \
  --entrypoint httpd \
  dhi.io/httpd:<tag> \
  -DFOREGROUND -e debug
```

Use this for interactive troubleshooting; logs go to stdout/stderr so you can see them with docker logs.

### Access a shell for debugging

The httpd runtime image includes a minimal shell (`/bin/sh`). To open a shell:

```bash
docker run --rm -it --entrypoint /bin/sh dhi.io/httpd:<tag>
```

For more comprehensive debugging tools, use `docker debug` or the `-dev` variant.

### Verify apachectl and binaries

Confirm apachectl (and other Apache binaries) exist at runtime:

```bash
docker run --rm --entrypoint /bin/sh dhi.io/httpd:<tag> -c "command -v /usr/local/apache2/bin/apachectl && command -v /usr/local/apache2/bin/httpd || true"
```

If apachectl is available you can use it with care (note that in containers the recommended pattern is to run httpd in
the foreground):

```bash
# show apachectl help
docker run --rm --entrypoint /usr/local/apache2/bin/apachectl dhi.io/httpd:<tag> -h
```

### View logs

Use docker logs for the container to view combined stdout/stderr (Apache has been configured to log to stdout/stderr):

```bash
docker logs my-httpd
```

## Non-hardened images vs. Docker Hardened Images

The following notes highlight key, tangible differences between the upstream (non-hardened) httpd image and this Docker
Hardened Image:

- Non-root user: The Docker Hardened httpd runtime variant runs as a nonroot user (www-data). Ensure any mounted files
  and directories have appropriate ownership/permissions for the nonroot user.

- Internal listening port: The upstream httpd image listens on port 80. The DHI listens on port 8080 (to avoid
  privileged ports which require root). Update your port mappings from `-p 80:80` to `-p 80:8080` or `-p 8080:8080`.

- Minimal runtime: Runtime variants are minimal and may omit shells and package managers. Use dev variants (tags with
  `dev`) for build-time or debugging workflows.

- Entrypoint: The upstream image uses CMD `["httpd-foreground"]` with no entrypoint. The DHI uses ENTRYPOINT
  `["httpd-foreground"]` with no cmd. This means arguments passed to `docker run` are appended to `httpd-foreground`
  rather than replacing the command. Use `--entrypoint` to run other commands (e.g., `--entrypoint httpd ... -t`).

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
