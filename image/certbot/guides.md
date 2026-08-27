## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this certbot image

This Docker Hardened Certbot image packages the core Certbot ACME client and its supporting library stack on a minimal
Debian-based runtime:

- `certbot` CLI — the EFF ACME client for issuing, renewing, and revoking TLS certificates
- `acme` Python library — the ACME protocol implementation used by Certbot
- Python 3.14 runtime, provided by `dhi/python`
- OpenSSL, provided by `dhi/pkg-openssl` (FIPS-validated provider in `-fips` variants)

DNS authenticator plugins (certbot-dns-cloudflare, certbot-dns-route53, and so on) and server integration plugins
(Apache, Nginx) are not included. For those use cases, see the
[upstream Certbot documentation](https://certbot.eff.org/docs/using.html#dns-plugins).

### Run the certbot container

Check the installed version:

```bash
docker run --rm dhi.io/certbot:<VERSION>-debian13 --version
```

Display the full help reference:

```bash
docker run --rm dhi.io/certbot:<VERSION>-debian13 --help all
```

List certificates already stored in a mounted configuration directory:

```bash
docker run --rm \
  -v ./letsencrypt:/etc/letsencrypt \
  dhi.io/certbot:<VERSION>-debian13 \
  certificates
```

## Issue a certificate

### Webroot authenticator (recommended)

The webroot authenticator places a validation file inside an existing web server's document root without binding to any
port itself. This approach works with the default nonroot user and does not require elevated privileges.

In the example below, your web server serves `/.well-known/acme-challenge/` from `./webroot`, and you mount your web
server's document root into the container:

```bash
docker run --rm \
  -v ./letsencrypt:/etc/letsencrypt \
  -v ./var-lib-letsencrypt:/var/lib/letsencrypt \
  -v ./webroot:/var/www/html \
  dhi.io/certbot:<VERSION>-debian13 \
  certonly \
  --webroot \
  --webroot-path /var/www/html \
  --email admin@example.com \
  --agree-tos \
  --no-eff-email \
  -d example.com
```

The image pre-provisions `/var/log/letsencrypt` and writes Certbot's debug log there. Mount
`-v ./letsencrypt-log:/var/log/letsencrypt` if you want renewal logs to persist across container restarts.

### Manual DNS authenticator

Use the manual DNS authenticator when your domain registrar does not have an automated plugin, or when running in an
environment without inbound HTTP access:

```bash
docker run --rm -it \
  -v ./letsencrypt:/etc/letsencrypt \
  -v ./var-lib-letsencrypt:/var/lib/letsencrypt \
  dhi.io/certbot:<VERSION>-debian13 \
  certonly \
  --manual \
  --preferred-challenges dns \
  --email admin@example.com \
  --agree-tos \
  --no-eff-email \
  -d example.com
```

Certbot will print a DNS TXT record to add to your zone. Once you have added it, press Enter to proceed.

### Standalone authenticator

The standalone authenticator starts a temporary HTTP server on port 80 to answer the ACME challenge. Because the DHI
runtime image runs as nonroot (uid 65532), binding to port 80 fails unless you take one of the following steps:

- Grant the `NET_BIND_SERVICE` capability:

  ```bash
  docker run --rm \
    --cap-add=NET_BIND_SERVICE \
    -p 80:80 \
    -v ./letsencrypt:/etc/letsencrypt \
    -v ./var-lib-letsencrypt:/var/lib/letsencrypt \
    dhi.io/certbot:<VERSION>-debian13 \
    certonly \
    --standalone \
    --email admin@example.com \
    --agree-tos \
    --no-eff-email \
    -d example.com
  ```

For most deployments the webroot or DNS authenticator is preferable because neither requires privileged port binding.

## Persistence

Certbot reads and writes three directories that must persist between container runs:

| Path                   | Purpose                                                                 |
| ---------------------- | ----------------------------------------------------------------------- |
| `/etc/letsencrypt`     | Certificate and key storage, account credentials, renewal configuration |
| `/var/lib/letsencrypt` | ACME working files (challenge tokens, backups)                          |
| `/var/log/letsencrypt` | Renewal and error logs                                                  |

All three paths in the DHI image are owned by uid/gid 65532 with mode `0770`.

### Using named volumes (recommended)

Named volumes are managed by Docker and avoid host permission issues:

```bash
docker run --rm \
  -v certbot-etc:/etc/letsencrypt \
  -v certbot-lib:/var/lib/letsencrypt \
  -v certbot-log:/var/log/letsencrypt \
  dhi.io/certbot:<VERSION>-debian13 \
  certificates
```

### Using host bind-mounts

If you need to access the certificate files directly from the host, create the directories first and set their ownership
to uid 65532:

```bash
mkdir -p ./letsencrypt ./var-lib-letsencrypt ./letsencrypt-log
chown -R 65532:65532 ./letsencrypt ./var-lib-letsencrypt ./letsencrypt-log

docker run --rm \
  -v ./letsencrypt:/etc/letsencrypt \
  -v ./var-lib-letsencrypt:/var/lib/letsencrypt \
  -v ./letsencrypt-log:/var/log/letsencrypt \
  dhi.io/certbot:<VERSION>-debian13 \
  certificates
```

## Non-hardened images vs. Docker Hardened Images

| Topic       | `certbot/certbot` (upstream)      | This image                                                      |
| ----------- | --------------------------------- | --------------------------------------------------------------- |
| Base        | Upstream-built image              | Minimal Debian-based hardened runtime                           |
| User        | Root (uid 0)                      | `nonroot` (uid/gid 65532); bind-mount ownership must match      |
| Shell       | Includes shell and utilities      | Runtime image has no shell; use **Docker Debug** for inspection |
| Plugins     | DNS and server plugins available  | Core `certbot` and `acme` packages only; no bundled plugins     |
| Entry point | `/usr/bin/certbot` wrapper script | `/usr/local/bin/certbot` symlink to the venv binary             |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

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

### Standalone authenticator fails with "permission denied" on port 80

The runtime image runs as nonroot (uid 65532). Binding to port 80 requires a privileged port capability. Either add
`--cap-add=NET_BIND_SERVICE` to your `docker run` command, or use the webroot, manual, or DNS authenticator instead,
none of which bind to privileged ports.

### "Permission denied" writing to /etc/letsencrypt

The `/etc/letsencrypt`, `/var/lib/letsencrypt`, and `/var/log/letsencrypt` directories in the image are owned by uid
65532\. When using host bind-mounts, the host directories must also be owned by uid 65532. Run
`chown -R 65532:65532 <directory>` on the host before mounting, or use named Docker volumes which do not have this
constraint.

### DNS plugin not found

DNS authenticator plugins such as `certbot-dns-cloudflare` and `certbot-dns-route53` are not bundled in this image. Only
the core `certbot` and `acme` packages are included. For DNS plugin support, refer to the
[upstream Certbot documentation](https://certbot.eff.org/docs/using.html#dns-plugins) for the upstream plugin images, or
use the manual DNS authenticator (`--manual --preferred-challenges dns`) as an alternative.
