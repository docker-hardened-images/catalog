## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this WordPress image

This Docker Hardened WordPress image provides a complete PHP-FPM environment optimized for WordPress:

- **WordPress Core**: Version 6.9.x bundled in the image (optional - can be replaced with your own)
- **PHP-FPM**: FastCGI Process Manager on port 9000 for high-performance PHP processing (PHP CLI not included - see
  below)
- **PHP Extensions**: 50+ extensions including all WordPress requirements:
  - **WordPress required**: mysqli, pdo_mysql, json, curl, dom, fileinfo, hash, mbstring, openssl, xml
  - **WordPress recommended**: gd, imagick, exif, zip, intl, bcmath, sodium
  - **Performance**: Zend OPcache for PHP acceleration
  - **Additional**: ctype, filter, iconv, libxml, mysqlnd, PDO, pdo_sqlite, posix, session, SimpleXML, sqlite3,
    tokenizer, xmlreader, xmlwriter, zlib, and more
- **ImageMagick**: Version 7.1.2+ built from source with full image processing capabilities
- **Security hardening**: Runs as nonroot user (uid/gid 65532), minimal attack surface
- **Optimized PHP configuration**: Tuned for WordPress with appropriate upload sizes, memory limits, and execution times

The image supports two deployment approaches:

1. **Bundled WordPress** (Quick Start): Use the WordPress version included in the image
1. **Custom WordPress** (Production): Mount your own WordPress sources for full version control

Note: PHP-FPM runs on port 9000 and requires a web server (nginx, Apache, Caddy) to handle HTTP requests and proxy to
PHP-FPM.

## Start a WordPress instance

### Quick start with bundled WordPress

The simplest way to get started uses the WordPress version bundled in the image:

```bash
docker run -d \
  --name wordpress \
  -p 9000:9000 \
  dhi.io/wordpress:<tag>
```

Note: This starts PHP-FPM on port 9000. You'll need a web server to proxy HTTP requests to it (see complete stack
example below).

### Production setup with custom WordPress

For production environments, mount your own WordPress sources:

```bash
docker run -d \
  --name wordpress \
  -v $(pwd)/wordpress:/var/www/html \
  -p 9000:9000 \
  dhi.io/wordpress:<tag>
```

This approach:

- Keeps WordPress sources in version control
- Allows independent control of WordPress updates
- Uses the image purely for PHP runtime and extensions
- Works with any WordPress version (not limited to 6.9)

## Common WordPress use cases

### Complete WordPress stack with nginx and MySQL

WordPress requires both a web server and database. This example provides a complete stack:

**Note**: Create the `nginx.conf` file using the configuration shown below before running `docker compose up`.

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

  db-init:
    image: dhi.io/mysql:8.4
    depends_on:
      db:
        condition: service_healthy
    command: >
      bash -c "mysql -h db -uroot -prootsecret <<EOF
        CREATE DATABASE IF NOT EXISTS wordpress;
        CREATE USER IF NOT EXISTS 'wordpress'@'%' IDENTIFIED BY 'changeme';
        GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'%';
        FLUSH PRIVILEGES;
      EOF"
    restart: "no"

  wordpress:
    image: dhi.io/wordpress:<tag>
    volumes:
      - wordpress-data:/var/www/html
    environment:
      WORDPRESS_DB_HOST: db
      WORDPRESS_DB_NAME: wordpress
      WORDPRESS_DB_USER: wordpress
      WORDPRESS_DB_PASSWORD: changeme
    depends_on:
      db-init:
        condition: service_completed_successfully

  nginx:
    image: dhi.io/nginx:1
    ports:
      - "80:80"
    volumes:
      - wordpress-data:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - wordpress

volumes:
  wordpress-data:
  db_data:
```

The `db-init` service runs once to create the WordPress database and user, then exits. WordPress waits for this
initialization to complete before starting.

Example nginx configuration for WordPress (`nginx.conf`):

**Note**: This image does not include `.htaccess` files since they are Apache-specific and have no effect with nginx or
PHP-FPM. The configuration below provides equivalent WordPress routing using nginx directives.

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
        listen 80;
        server_name example.com;
        root /var/www/html;
        index index.php;

        location / {
            # WordPress permalinks - equivalent to .htaccess rewrite rules
            try_files $uri $uri/ /index.php?$args;
        }

        location ~ \.php$ {
            fastcgi_pass wordpress:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            # Pass HTTP_AUTHORIZATION header (WordPress requirement)
            fastcgi_param HTTP_AUTHORIZATION $http_authorization;
            include fastcgi_params;
        }

        location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
            expires 30d;
            add_header Cache-Control "public, immutable";
        }

        location ~ /\.ht {
            deny all;
        }
    }
}
```

### Adding custom PHP extensions

The image includes 50+ PHP extensions for WordPress. If you need additional extensions (e.g., redis, mongodb), use a
multi-stage build using dhi/php as the builder base.

```dockerfile
# Stage 1: Compile extension using dev variant
FROM dhi.io/php:8.3-dev as builder

# Add any additional  
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
    # Copy compiled extension to staging
    mkdir -p /extensions && \
    cp $(php-config --extension-dir)/apcu.so /extensions/ && \
    # Create config file
    mkdir -p /ext-config && \
    echo "extension=apcu.so" > /ext-config/docker-php-ext-apcu.ini

# Stage 2: Runtime image with extension
FROM dhi.io/wordpress:6.9-php8.3-fpm

ARG PHP_EXT_DIR=/opt/php-8.3/lib/php/extensions/no-debug-non-zts-20230831
ARG PHP_CONF_DIR=/opt/php-8.3/etc/php/conf.d

# Copy both extension binary and config
COPY --from=builder /extensions/apcu.so "${PHP_EXT_DIR}/"
COPY --from=builder /ext-config/docker-php-ext-apcu.ini "${PHP_CONF_DIR}/"
```

## Docker Official Images vs. Docker Hardened Images

### Key differences

| Feature         | Docker Official WordPress           | Docker Hardened WordPress                           |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt available                       | No package manager in runtime variants              |
| User            | Runs as www-data (uid 33)           | Runs as nonroot user (uid/gid 65532)                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |
| PHP Extensions  | Same WordPress extensions           | Same WordPress extensions                           |
| WordPress       | Multiple variants (Apache, FPM)     | PHP-FPM only (pair with your web server)            |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- WP-CLI in a separate container for WordPress management

For example, you can use Docker Debug:

```bash
docker debug wordpress
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:wordpress \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/wordpress:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run WordPress

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

| Item               | Migration note                                                                                                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                   |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user (uid/gid 65532). Ensure that necessary files and directories are accessible to the nonroot user.                  |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                            |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                          |
| Ports              | Non-dev hardened images run as a nonroot user by default. PHP-FPM's default port 9000 is not affected by this limitation and works without any special configuration.                       |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary. |
| Apache vs PHP-FPM  | Docker Hardened WordPress uses PHP-FPM only. If migrating from Apache-based images, you'll need to add a web server (nginx, Caddy, or Apache) to proxy requests to PHP-FPM on port 9000.    |
| File permissions   | WordPress uploads and plugin/theme installations require write permissions. Ensure wp-content/uploads and related directories are writable by the nonroot user (uid/gid 65532).             |
| WordPress version  | The image tag indicates the bundled WordPress version. For production, consider mounting your own WordPress sources for version control. The PHP runtime works with any WordPress version.  |
| Web server setup   | Unlike Apache-based WordPress images, this image requires a separate web server container. Configure nginx or another web server to proxy to PHP-FPM on port 9000 (see examples above).     |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   WordPress images are available with PHP 8.3 and 8.4.

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

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

For WordPress-specific debugging:

```bash
# View PHP-FPM logs
docker logs wordpress

# Use Docker Debug for interactive troubleshooting
docker debug wordpress

# Check PHP-FPM configuration
docker exec wordpress php-fpm -i | grep -i wordpress
```

### Permissions

By default image variants intended for runtime, run as the nonroot user (uid/gid 65532). Ensure that necessary files and
directories are accessible to the nonroot user. You may need to copy files to different directories or change
permissions so your application running as the nonroot user can access them.

For WordPress specifically:

- `wp-content/uploads` must be writable for media uploads
- `wp-content/plugins` and `wp-content/themes` must be writable if installing via WordPress admin
- `wp-config.php` should be readable but not writable for security

Set permissions correctly:

```bash
# Make uploads directory writable
chown -R 65532:65532 wordpress/wp-content/uploads
chmod -R 755 wordpress/wp-content/uploads

# For plugin/theme installation via admin
chown -R 65532:65532 wordpress/wp-content/plugins
chown -R 65532:65532 wordpress/wp-content/themes
```

### Privileged ports

Non-dev hardened images run as a nonroot user by default. PHP-FPM's default port 9000 is not affected by this limitation
and works without any special configuration. Your web server (nginx, Apache) will bind to ports 80/443, not the
WordPress container.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

The WordPress image uses `php-fpm` as its entry point. If you need to customize the entry point, ensure PHP-FPM
continues to run in the foreground.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.
