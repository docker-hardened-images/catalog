## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/matomo:<version>`
- Mirrored image: `<your-namespace>/dhi-matomo:<version>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Matomo image

This Docker Hardened Image ships the Matomo application files and the PHP-FPM runtime needed to execute them. It listens
on port 9000/tcp using the FastCGI protocol and is designed to run behind a web server such as Nginx. Matomo requires a
MySQL or MariaDB database; none is included in this image.

## Start Matomo

Matomo needs a database and a web server in front of PHP-FPM. Use the following Docker Compose file as a starting point,
replacing `<version>` with the desired version:

```yaml
services:
  db:
    image: dhi.io/mariadb:11.4
    environment:
      MARIADB_DATABASE: matomo
      MARIADB_USER: matomo
      MARIADB_PASSWORD: change-me
      MARIADB_ROOT_PASSWORD: change-me-too
    volumes:
      - db:/var/lib/mysql

  matomo:
    image: dhi.io/matomo:<version>
    environment:
      MATOMO_DATABASE_HOST: db
      MATOMO_DATABASE_USERNAME: matomo
      MATOMO_DATABASE_PASSWORD: change-me
      MATOMO_DATABASE_DBNAME: matomo
    depends_on:
      - db
    volumes:
      - matomo:/var/www/html

  nginx:
    image: dhi.io/nginx:1-debian13
    ports:
      - "80:80"
    depends_on:
      - matomo
    volumes:
      - matomo:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro

volumes:
  db:
  matomo:
```

The Nginx configuration file (`nginx.conf`) should include the following configuration for Matomo:

```nginx
server {
    listen 80;

    root /var/www/html;
    index index.php;

    client_max_body_size 100m;

    location = /favicon.ico {
        log_not_found off;
    }

    location ~ ^/(index|matomo|piwik|js/index).php$ {
        fastcgi_pass matomo:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location / {
        try_files $uri $uri/ =404;
    }

    # deny access to internal Matomo directories that must never be served
    location ~ ^/(config|tmp|core|lang)/ {
        deny all;
        return 403;
    }

    location ~ /\.(?!well-known) {
        deny all;
        return 403;
    }
}
```

Then start the services with:

```bash
docker compose up -d
```

Browse to `http://localhost` to complete the Matomo installation wizard. The database connection fields are pre-filled
from the `MATOMO_DATABASE_*` environment variables set above.

### Running scheduled archiving

Matomo pre-processes ("archives") reports in the background so the dashboard stays fast. Run this on a schedule (for
example, every hour) against a running container:

```bash
docker compose exec matomo php console core:archive
```

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Feature             | DOI (`matomo`)                                          | DHI (`dhi.io/matomo`)                             |
| ------------------- | ------------------------------------------------------- | ------------------------------------------------- |
| User                | root (entrypoint drops to www-data for php-fpm workers) | `nonroot` (runtime/FIPS)                          |
| Shell               | Full shell (bash/sh) available                          | No (runtime/FIPS)                                 |
| Package manager     | apt available                                           | No (runtime/FIPS)                                 |
| Binary path         | `/usr/local/bin/php`                                    | `/usr/bin/php`                                    |
| Zero CVE commitment | No                                                      | Yes                                               |
| FIPS variant        | No                                                      | Yes (`-fips`, `-fips-dev`)                        |
| Base OS             | Debian                                                  | Docker Hardened Images (Debian 13 or Alpine 3.24) |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

**Runtime variants** are designed to run Matomo in production. These images typically:

- Run as a nonroot user
- Do not include a shell or a package manager
- Contain only the Matomo application, PHP-FPM, and the extensions Matomo requires

**Dev variants** include `dev` in the tag (for example, `5-dev`). They are intended for multi-stage Dockerfiles or
interactive troubleshooting. These images typically:

- Run as root
- Include a shell and package manager (`apt` on Debian, `apk` on Alpine)
- Ship the same application files as the runtime image

**FIPS variants** include `fips` in the tag. They use cryptographic modules that have been validated under FIPS 140, a
U.S. government standard for secure cryptographic operations.

For debugging minimal runtime containers without a shell, you can use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to running containers.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or Kubernetes manifests. At
minimum, you must update the base image in your existing deployment to a Docker Hardened Image. Common changes:

| Item               | Migration note                                                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image         | Replace your base images with a Docker Hardened Image.                                                                                     |
| Package management | Non-dev images don't contain package managers. Use package managers only in images with a dev tag.                                         |
| Non-root user      | By default, non-dev images run as the nonroot user. Ensure necessary files and directories are accessible to the nonroot user.             |
| Multi-stage build  | Use dev-tagged images for build stages and non-dev images for runtime.                                                                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default.                                                                       |
| Entry point        | Docker Hardened Images may have different entry points than upstream images. Inspect entry points and update your deployment if necessary. |
| No shell           | By default, non-dev images don't contain a shell. Use dev images in build stages and copy artifacts to the runtime stage.                  |

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers.

### Permissions

By default image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user.

### Entry point

Docker Hardened Images may have different entry points than upstream Matomo images. Use `docker inspect` to inspect
entry points and update your deployment if necessary.
