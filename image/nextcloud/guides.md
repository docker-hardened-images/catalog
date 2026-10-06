## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Nextcloud image

| Tool          | Description                                                                  |
| ------------- | ---------------------------------------------------------------------------- |
| `nextcloud`   | The Nextcloud server application files, served from `/var/www/html`.         |
| `php`         | PHP runtime used to execute Nextcloud code.                                  |
| `php-fpm`     | PHP FastCGI Process Manager that serves Nextcloud to an upstream web server. |
| `occ`         | Nextcloud command line management tool.                                      |
| `imagemagick` | Image processing tools used by Nextcloud for previews and thumbnails.        |

### Run the Nextcloud container

Nextcloud needs a web server in front of it and a database behind it. The minimal shape is an nginx container sharing
the application volume with this one, plus PostgreSQL or MySQL.

```console
$ docker run -d --name nextcloud \
    -e POSTGRES_HOST=db \
    -e POSTGRES_DB=nextcloud \
    -e POSTGRES_USER=nextcloud \
    -e POSTGRES_PASSWORD=example \
    -e NEXTCLOUD_ADMIN_USER=admin \
    -e NEXTCLOUD_ADMIN_PASSWORD=example \
    -e NEXTCLOUD_TRUSTED_DOMAINS=nextcloud.example.com \
    -v nextcloud:/var/www/html \
    <image>
```

On first start the entrypoint copies the application into `/var/www/html` and, when database credentials are present,
runs the installer. Administrative tasks use the `occ` command line tool:

```console
$ docker exec -u 65532 nextcloud php /var/www/html/occ status
```

### Configuration

| Variable                                            | Description                                              |
| --------------------------------------------------- | -------------------------------------------------------- |
| `NEXTCLOUD_ADMIN_USER` / `NEXTCLOUD_ADMIN_PASSWORD` | Creates the initial administrator during installation.   |
| `NEXTCLOUD_TRUSTED_DOMAINS`                         | Space separated hostnames allowed to serve the instance. |
| `NEXTCLOUD_DATA_DIR`                                | Data directory. Defaults to `/var/www/html/data`.        |
| `POSTGRES_*` / `MYSQL_*` / `SQLITE_DATABASE`        | Database selection and credentials.                      |
| `PHP_MEMORY_LIMIT` / `PHP_UPLOAD_LIMIT`             | PHP limits. Both default to `512M`.                      |
| `REDIS_HOST` / `REDIS_HOST_PORT`                    | Optional Redis cache used for file locking.              |

`NEXTCLOUD_ADMIN_USER`, `NEXTCLOUD_ADMIN_PASSWORD`, `MYSQL_*`, `POSTGRES_*`, and `REDIS_HOST_PASSWORD` also accept a
`_FILE` suffixed form that reads the value from a file, for use with Docker secrets; the other variables above have no
such handling. Persist `/var/www/html` and the configured data directory; both must remain writable by uid `65532`.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

| Variant  | Tag suffix  | User            | Shell | Package manager | Use it for                                  |
| -------- | ----------- | --------------- | ----- | --------------- | ------------------------------------------- |
| Runtime  | none        | `nonroot` 65532 | yes   | no              | Production.                                 |
| Dev      | `-dev`      | `root`          | yes   | `apt`           | Debugging, installing extra Nextcloud apps. |
| FIPS     | `-fips`     | `nonroot` 65532 | yes   | no              | Production under FIPS 140 requirements.     |
| FIPS dev | `-fips-dev` | `root`          | yes   | `apt`           | Debugging a FIPS deployment.                |

The runtime variant retains a shell because the upstream entrypoint is a shell script that installs and upgrades the
application on start. It does not include a package manager.

## Migrate to a Docker Hardened Image

The upstream project publishes `-apache`, `-fpm`, and `-fpm-alpine` tags. This image corresponds to **`-fpm`**.

Deliberate differences from the upstream image:

- **PHP-FPM only.** The upstream `-apache` tag is not reproduced; run a separate hardened web server instead.
- **No bundled cron.** Upstream ships a crontab to run `cron.php`. Schedule that externally, for example with a
  Kubernetes `CronJob`, and select `occ background:cron`.
- **No in-place updater.** The `updater/` directory is removed. Upgrade by deploying a newer image tag.
- **Runs as uid 65532.** The upstream image starts as root and drops privileges; this image never runs as root in the
  runtime variant.

| Item          | Migration note                                                                                                                                                                   |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Web server    | If you currently run the `-apache` tag, add a separate web server (nginx, Apache, Caddy) and forward PHP requests to this container on port `9000`. See the example below.       |
| Cron          | No crontab or cron daemon is bundled (the Alpine image ships `busybox` only as the entrypoint's shell). Schedule `cron.php` externally; see [Background jobs](#background-jobs). |
| Updates       | The `updater/` directory is removed. Upgrade by deploying a newer image tag rather than using the in-place updater.                                                              |
| Non-root user | The runtime, FIPS, and FIPS dev variants run as the nonroot user (uid/gid 65532) and never as root. Ensure `/var/www/html` and the data directory remain writable by it.         |
| Extra apps    | Install additional Nextcloud apps as described in [Installing additional apps](#installing-additional-apps) rather than modifying the image in place.                            |

If you currently run the `-apache` tag, point your web server at the shared `/var/www/html` volume and forward PHP to
this container on port `9000`:

```nginx
upstream php-handler {
    server nextcloud:9000;
}

server {
    listen 80;
    root /var/www/html;
    index index.php;
    client_max_body_size 512M;

    location ~ \.php(?:$|/) {
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info;
        fastcgi_param front_controller_active true;
        fastcgi_pass php-handler;
    }

    location / {
        try_files $uri $uri/ /index.php$request_uri;
    }
}
```

Both containers must mount the same volume at `/var/www/html`.

## Background jobs

This image does not ship a cron daemon. Nextcloud still needs `cron.php` executed roughly every five minutes.

Set the job mode once:

```console
$ docker exec -u 65532 nextcloud php /var/www/html/occ background:cron
```

Then schedule it externally. On Kubernetes, a `CronJob` running `php /var/www/html/occ` against the same volume is the
usual approach. With Compose, a small sidecar looping on a sleep works.

## Installing additional apps

The image ships `/usr/share/nextcloud/custom_apps` (owned by uid 65532), and the entrypoint seeds it into the running
volume's `/var/www/html/custom_apps` only when that directory doesn't yet exist or is still empty, which is the case on
a fresh install. Writing to `/usr/share/nextcloud/custom_apps` after a volume has already been initialized has no
effect, since the seeding step won't run again.

For an already-running instance, install apps directly into the volume's `custom_apps` directory (writable by uid
65532), either through the Nextcloud app store in the web UI or by copying app files into `/var/www/html/custom_apps` on
the mounted volume. To bake apps into the image itself for a fresh deployment, add them to
`/usr/share/nextcloud/custom_apps` in a derived image built from the `-dev` variant before the volume is first
initialized.

## Available PHP extensions

Beyond the PHP defaults, this image builds `apcu`, `bcmath`, `exif`, `ftp`, `gd`, `gmp`, `igbinary`, `imagick`, `ldap`,
`memcached`, `pcntl`, `pdo_mysql`, `pdo_pgsql`, `redis`, `sysvsem`, and `zip`. `intl` is also loaded, from the base
`php-8.5` package rather than either build step. Confirm what is loaded with:

```console
$ docker run --rm <image> php -m
```

## FIPS

The `-fips` tags link PHP against a FIPS validated OpenSSL provider. Nextcloud itself performs no cryptography outside
OpenSSL, so no application configuration is required. Verify the provider is active by requesting a digest FIPS
disallows; MD5 is rejected under FIPS, so the call returns `bool(false)` instead of a hash:

```console
$ docker run --rm <image>-fips php -r 'var_dump(openssl_digest("fips", "md5"));'
bool(false)
```

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The runtime variant retains a shell, since the upstream entrypoint needs one, but has no package manager. For deeper
debugging tools, use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to the container.

### Permissions

`/var/www/html` and the configured data directory must remain writable by uid `65532`. If you mount a volume that was
populated by a different user, `chown` it to `65532:65532` before starting the container.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary. This image's entry point is
`/entrypoint.sh`, matching upstream's `-fpm` tag.
