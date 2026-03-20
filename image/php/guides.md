## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What’s included in this PHP image

This Docker Hardened PHP image includes PHP runtime and essential tools in a single, security-hardened package:

- `php`: PHP command-line interpreter and runtime environment (non-FPM variants only)
- `php-fpm`: FastCGI Process Manager for serving PHP applications (FPM variant only)
- `phpdbg`: a lightweight, powerful, easy to use debugging platform for PHP (dev variant only)
- Essential PHP extensions built-in/statically compiled
- Full phpize environment (`phpize`, `php-config`, compiler, PHP source code) for building extensions (dev variant only)

## Start a PHP image

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run dhi.io/php:<tag> --version
```

## Common PHP use cases

### Running a PHP script

Execute PHP scripts directly from the command line.

```bash
docker run --rm -v $(pwd):/app -w /app dhi.io/php:<tag> php script.php
```

### Serving a PHP application with PHP-FPM

Use the FPM variant to serve PHP applications through a FastCGI gateway like Nginx.

```dockerfile
FROM dhi.io/php:<tag>-fpm
COPY . /var/www/html
EXPOSE 9000
```

### Customizing PHP configuration with $PHP_INI_DIR

Configure PHP settings by adding custom ini files to the PHP configuration directory.

```dockerfile
FROM dhi.io/php:<tag>
COPY custom-php.ini $PHP_INI_DIR/conf.d/
```

### Building custom PHP extensions (dev variant)

Use the dev variant to compile and install additional PHP extensions.

Multi-stage build:

```dockerfile
FROM dhi.io/php:<tag>-dev AS builder
WORKDIR /tmp
```

Example of building Redis extension manually:

```dockerfile
RUN pecl install redis

FROM dhi.io/php:<tag>-fpm
COPY --from=builder $PHP_PREFIX/lib/php/extensions $PHP_PREFIX/lib/php/extensions
```

Add extension configuration:

```dockerfile
RUN echo "extension=redis.so" > $PHP_INI_DIR/conf.d/redis.ini
```

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature                  | Docker Official PHP                                              | Docker Hardened PHP                                                                           |
| ------------------------ | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Security                 | Standard base with common utilities                              | Minimal, hardened base with security patches                                                  |
| Shell access             | Full shell (bash/sh) available                                   | No shell in runtime variants                                                                  |
| Package manager          | apt/apk available                                                | No package manager in runtime variants                                                        |
| User                     | Runs as root by default                                          | Runs as nonroot user                                                                          |
| Attack surface           | Larger due to additional utilities                               | Minimal, only essential components                                                            |
| Debugging                | Traditional shell debugging                                      | Use Docker Debug or Image Mount for troubleshooting                                           |
| Apache support           | mod_php available via apache2 variant                            | No mod_php support, FPM/FastCGI only                                                          |
| Extension building tools | docker-php-ext-\* helper scripts for easy extension installation | No helper scripts, but PHP source in $PHP_SRC_DIR and full phpize environment in -dev variant |
| Extension installation   | Simplified with docker-php-ext-install, docker-php-ext-configure | Manual installation using standard phpize/configure/make process                              |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```bash
docker debug <image-name>
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-php \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/php:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

### PHP-specific variants

- `fpm`: FastCGI Process Manager variant for serving PHP applications through a FastCGI gateway (e.g., Nginx, Apache).
  This is the recommended way to serve PHP applications in production.
- `dev`: Development variant that includes build tools, a shell, APT package manager, PECL for extension management, and
  full compiler/phpize environment as well as the PHP source code for building custom extensions.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                 |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                    |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                        |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. PHP-FPM default port 9000 works without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                               |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                               |
| Apache to FPM      | Users of the -apache2 variant must migrate to FPM/FastCGI as mod_php is not supported. Configure your web server to proxy PHP requests to the FPM service.                                                                                                                |
| Custom extensions  | Extensions not included in the image must be built using the -dev variant in a multi-stage build process.                                                                                                                                                                 |
| Removed features   | The mhash compatibility feature is not enabled (mhash has been deprecated since PHP 7.0.0 - use the hash extension instead).                                                                                                                                              |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   For PHP applications, you'll typically want the `-fpm` variant for production.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For PHP
   applications, this is typically going to be an image tagged as `-dev` because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `-dev`, your
   final runtime stage should use a non-dev image variant like `-fpm`.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `-dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `-dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Migrating from Apache mod_php

The Docker Hardened PHP image does not support the Apache mod_php variant. Applications using the `-apache2` variant of
the Docker Official Image must migrate to use PHP-FPM with a separate web server.

Example migration approach using Docker Compose:

```yaml
version: "3.8"
services:
  php:
    image: dhi.io/php:<tag>-fpm
    volumes:
      - ./src:/var/www/html

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./src:/var/www/html
      - ./nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - php
```

Example nginx configuration for PHP-FPM:

```
server {
    listen 80;
    server_name localhost;
    root /var/www/html;
    index index.php index.html;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
```

### Building custom PHP extensions

Extensions not included in the base image must be built using the `-dev` variant. While Docker Hardened Images don't
include the `docker-php-ext-*` helper scripts found in Docker Official Images, the PHP source code is available in
`$PHP_SRC_DIR` and a full phpize environment is present in the `-dev` variant.

Note that the `mhash` compatibility layer (deprecated since PHP 7.0.0) is not enabled - applications should use the
modern `hash` extension instead.

Use a multi-stage build to compile extensions using the standard PHP build process.

Building an extension from PECL:

```dockerfile
FROM dhi.io/php:<tag>-dev AS builder
WORKDIR /tmp
RUN pecl download redis \
    && tar xzf redis-*.tgz \
    && cd redis-* \
    && phpize \
    && ./configure \
    && make \
    && make install

FROM dhi.io/php:<tag>-fpm
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
RUN echo "extension=redis.so" > $PHP_INI_DIR/conf.d/redis.ini
```

Building an extension from source:

```dockerfile
FROM dhi.io/php:<tag>-dev AS builder
WORKDIR /tmp
RUN git clone https://github.com/phpredis/phpredis.git \
    && cd phpredis \
    && phpize \
    && ./configure \
    && make \
    && make install

FROM dhi.io/php:<tag>-fpm
COPY --from=builder /usr/local/lib/php/extensions /usr/local/lib/php/extensions
RUN echo "extension=redis.so" > $PHP_INI_DIR/conf.d/redis.ini
```

### Legacy mhash functions

The `mhash` extension has been deprecated since PHP 7.0.0 and its functionality has been integrated into the `hash`
extension. Docker Hardened PHP images do not include the mhash compatibility layer. If your application uses legacy
`mhash_*` functions, you should update your code to use the modern `hash` equivalents:

- Replace `mhash()` with `hash()`
- Replace `mhash_get_hash_name()` with `hash_algos()`
- Replace `mhash_get_block_size()` with a custom implementation using `hash()`
- Replace `mhash_count()` with `count(hash_algos())`

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. PHP-FPM's
default port 9000 works without issues.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
