## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/cloudflared:<tag>`
- Mirrored image: `<your-namespace>/dhi-cloudflared:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

cloudflared is the command-line client for Cloudflare Tunnel™. It connects an origin service to the Cloudflare® network.
Configuration and advanced usage are documented in the upstream project at https://github.com/cloudflare/cloudflared.
This image is the hardened stand-in for `docker.io/cloudflare/cloudflared`.

The container entrypoint is `cloudflared --no-autoupdate`, and the default command is `version`. Pass a subcommand, such
as `tunnel`, as a container argument. The entrypoint already supplies the `cloudflared` binary.

The runtime image runs as numeric user 65532 (account name `nonroot`). The working directory on every variant is
`/home/nonroot`. The client searches `/home/nonroot/.cloudflared` first (mode `0700`, owned by uid 65532). Also present,
and owned by uid 65532, are `/etc/cloudflared` (mode `0755`), `/usr/local/etc/cloudflared` (mode `0700`), and
`/var/log/cloudflared` (mode `0770`).

The image sets `SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt`. FIPS variants, published as
`dhi.io/cloudflared:<tag>-fips` and `dhi.io/cloudflared:<tag>-fips-dev`, also set `OPENSSL_CONF` and `OPENSSL_MODULES`.

## Start a cloudflared image

### Check the version

```bash
docker run --rm dhi.io/cloudflared:<tag>
```

The process prints the client version and exits. The same line includes a parenthetical build stamp. Treat that stamp as
a reproducible build epoch, rather than the upstream release date.

### Show tunnel help

```bash
docker run --rm dhi.io/cloudflared:<tag> tunnel --help
```

Arguments are appended to the entrypoint `cloudflared --no-autoupdate`. The help text lists default metrics listen
addresses `0.0.0.0:20241` through `0.0.0.0:20245`.

## Common cloudflared use cases

### Metrics

Start a metrics listener on port 20241 pointed at a local origin URL. After the log line
`Starting metrics server on [::]:20241/metrics`, the metrics server is listening. That listener comes up even when the
process cannot reach the Cloudflare edge.

```bash
docker run --rm -p 20241:20241 dhi.io/cloudflared:<tag> tunnel --metrics 0.0.0.0:20241 --url http://127.0.0.1:9
```

Leave that container running. From the host:

```bash
curl http://127.0.0.1:20241/metrics
curl http://127.0.0.1:20241/healthcheck
```

`/metrics` returns HTTP 200 and the body contains `version=` set to the client version. `/healthcheck` returns HTTP 200
and the body `OK`.

### Use the dev variant

The runtime image has no shell. The dev image includes bash, and its configured user is root. This command starts bash
as uid 65532, the runtime user, and writes a file in the config directory:

```bash
docker run --rm --user 65532:65532 --entrypoint bash dhi.io/cloudflared:<tag>-dev -c 'touch /home/nonroot/.cloudflared/probe && cloudflared version'
```

The command prints the same client version line as the runtime image.

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
