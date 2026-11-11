## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/openspeedtest:<tag>`
- Mirrored image: `<your-namespace>/dhi-openspeedtest:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

OpenSpeedTest is a self-hosted HTML5 network speed test. Full project documentation is at https://openspeedtest.com and
https://github.com/openspeedtest/Speed-Test. This image replaces `openspeedtest/latest`.

## Start an OpenSpeedTest image

The server listens on port 3000 for HTTP and port 3001 for HTTPS. There is no `openspeedtest` binary on `PATH`. nginx is
the server, and the entrypoint is `/docker-entrypoint.sh`. A command you append to `docker run` is executed by that
entrypoint.

### Run the server

```bash
$ docker run -d --name openspeedtest \
  -p 3000:3000 \
  -p 3001:3001 \
  dhi.io/openspeedtest:<tag>
```

Open http://127.0.0.1:3000/ for HTTP. The response is the speed-test page, and the body contains `OpenSpeedTest`:

```bash
$ curl -fsS http://127.0.0.1:3000/ | grep -F 'OpenSpeedTest'
```

HTTPS uses the certificate generated in the image. Browsers warn because that certificate is self-signed
(`CN=localhost`). `curl` needs `-k` for the same reason:

```bash
$ curl -kfsS -o /dev/null -w '%{http_code}\n' https://127.0.0.1:3001/
```

The page downloads `/downloading` and posts the upload test to `/upload`:

```bash
$ curl -fsS -D - -o /dev/null http://127.0.0.1:3000/downloading | grep -i '^Content-Length:'
$ curl -fsS -o /dev/null -w '%{http_code}\n' -X POST http://127.0.0.1:3000/upload
```

`GET /downloading` returns `Content-Length: 31457280`. `POST /upload` returns `200`.

### Run nginx directly

```bash
$ docker run --rm dhi.io/openspeedtest:<tag> nginx -v
```

The command prints the bundled nginx version and exits.

### Use your own TLS certificate

The image stores a self-signed certificate at `/etc/ssl/nginx.crt` and the key at `/etc/ssl/nginx.key`. Both files are
mode `0444`, and the certificate subject is `CN=localhost`. Replace them by mounting your own files at those two paths.
The files must be readable by UID 65532. Mounting a directory over `/etc/ssl` hides the CA bundle, so mount the two
files. Run the following commands from the directory that contains `nginx.crt` and `nginx.key`:

```bash
$ chmod 0444 nginx.crt nginx.key
$ docker run -d --name openspeedtest \
  -p 3000:3000 \
  -p 3001:3001 \
  -v "$PWD/nginx.crt:/etc/ssl/nginx.crt:ro" \
  -v "$PWD/nginx.key:/etc/ssl/nginx.key:ro" \
  dhi.io/openspeedtest:<tag>
```

If a container named `openspeedtest` is already running, remove it before this command. Confirm HTTPS still answers:

```bash
$ curl -kfsS -o /dev/null -w '%{http_code}\n' https://127.0.0.1:3001/
```

### Document root

nginx serves files from `/usr/share/openspeedtest`. `/usr/share/nginx/html` is a symlink to that directory, so either
path reaches the same files. The directory is writable by UID 65532.

### Change the listen ports

Set `CHANGE_CONTAINER_PORTS` to `True` and set `HTTP_PORT` and `HTTPS_PORT`. The default command rewrites every `3000`
and `3001` listener, including the IPv6 lines, then starts nginx. Publish the new container ports:

```bash
$ docker run -d --name openspeedtest \
  -e CHANGE_CONTAINER_PORTS=True \
  -e HTTP_PORT=3100 \
  -e HTTPS_PORT=3101 \
  -p 3100:3100 \
  -p 3101:3101 \
  dhi.io/openspeedtest:<tag>
```

```bash
$ curl -fsS -o /dev/null -w '%{http_code}\n' http://127.0.0.1:3100/
```

The command prints `200`.

`DOMAIN_NAME` replaces `YOURDOMAIN` in the server name. `ALLOW_ONLY` is a semicolon-separated origin allow-list.
`SET_SERVER_NAME` inserts a heading into `INDEX_HTML`. `VERIFY_OWNERSHIP` writes `/usr/share/nginx/html/Verify.txt` when
that file is absent. `CONFIG` is the server file, `/etc/nginx/conf.d/OpenSpeedTest-Server.conf`.

Let's Encrypt issuance and cron are not included. `ENABLE_LETSENCRYPT=True` does not run certbot. Mount
`/etc/ssl/nginx.crt` and `/etc/ssl/nginx.key` to use your own certificate. These directories exist and are writable by
UID 65532:

- `/var/log/letsencrypt`
- `/etc/letsencrypt`
- `/var/lib/letsencrypt`

The runtime user is `nginx` (UID 65532). `SET_USER` is `65532`. The working directory is `/`. Docker stops the container
with `SIGQUIT`. The default command is `/entrypoint.sh`, which execs `nginx -g 'daemon off;'`.

### Development image

Runtime tags run as UID 65532 and do not include bash. A development tag (the tag includes `dev`) runs as root and
includes bash and a package manager (`apt` on Debian, `apk` on Alpine):

```bash
$ docker run --rm dhi.io/openspeedtest:<tag>-dev bash -c 'id -u'
```

The command prints `0`.

## Non-hardened images vs. Docker Hardened Images

Migration off `openspeedtest/latest` depends on the differences above:

- The entrypoint is `/docker-entrypoint.sh`. The default command is `/entrypoint.sh`, which applies the port, domain,
  and page switches and then execs nginx. A command you pass, such as `nginx -v`, replaces `/entrypoint.sh`.
- The document root is `/usr/share/openspeedtest`, and `/usr/share/nginx/html` links to it.
- TLS files are `/etc/ssl/nginx.crt` and `/etc/ssl/nginx.key`. Mount those two files.
- Container ports are `3000/tcp` and `3001/tcp`.
- The runtime user is UID 65532. Development tags run as root and include a shell.

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
