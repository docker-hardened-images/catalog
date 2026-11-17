## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/configurable-http-proxy:<tag>`
- Mirrored image: `<your-namespace>/dhi-configurable-http-proxy:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Getting started with Configurable HTTP Proxy

[Configurable HTTP Proxy](https://github.com/jupyterhub/configurable-http-proxy) (CHP) is a Node.js reverse proxy with a
REST API for dynamic routing. It is commonly deployed in front of [JupyterHub](https://jupyterhub.readthedocs.io/) to
add, remove, and update routes while the proxy stays running.

This Docker Hardened Image runs the same application code as the upstream project, with a minimal runtime (no shell in
production variants) and a non-root user.

### Run the proxy

The image exposes **8000/tcp** (HTTP traffic) and **8001/tcp** (API). The default command binds the API to all
interfaces (`--api-ip=0.0.0.0`) so the API is reachable when port mappings are published.

Use a **timeout** so a foreground `docker run` does not block forever (the process runs until stopped):

```bash
timeout 120 docker run --rm \
  -p 8000:8000 -p 8001:8001 \
  dhi.io/configurable-http-proxy:5.1.1-debian13
```

From another terminal on the host, you can list routes (empty object `{}` when none are configured):

```bash
curl -sS http://127.0.0.1:8001/api/routes
```

### Configuration

- **CLI flags**: Pass arguments after the image name (they are appended to the default command). For available options,
  see [Show help](#show-help).
- **`CONFIGPROXY_AUTH_TOKEN`**: If set, requests to the API must include this token (for example via the `Authorization`
  header). Set it when exposing the API beyond trusted networks.
- **`NODE_ENV`**: The image sets `NODE_ENV=production` by default.

The upstream Docker Official Image uses a shell entrypoint script that can load `CONFIGPROXY_AUTH_TOKEN` from a file
referenced by `CONFIGPROXY_AUTH_TOKEN_FILE`. This hardened image does **not** include that script; set
`CONFIGPROXY_AUTH_TOKEN` (or inject the equivalent via your orchestrator) if you need API authentication.

### Show help

```bash
docker run --rm dhi.io/configurable-http-proxy:5.1.1-debian13 --help
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature          | Non-hardened upstream image (`jupyterhub/configurable-http-proxy`) | Docker Hardened configurable-http-proxy                                                      |
| ---------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| Entry point      | `chp-docker-entrypoint` shell script                               | `node` and the CLI script path (no shell script)                                             |
| Shell            | BusyBox `sh` available                                             | No shell in runtime variants                                                                 |
| User             | Numeric `65534` (typically `nobody` in the upstream base)          | Default Docker Hardened Images `nonroot` user (uid/gid 65532) from `image/.nonroot.inc.yaml` |
| API reachability | Script may set defaults                                            | Default `--api-ip=0.0.0.0` so the API listens on all interfaces                              |
| Debugging        | Shell inside the container                                         | Use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) or similar tooling   |

### Why no shell?

Docker Hardened Images prioritize a minimal runtime: fewer binaries, a smaller attack surface, and no interactive shell
in production images. For troubleshooting, use Docker Debug or mount debug tooling as described in
[Troubleshooting migration](#troubleshooting-migration).

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

| Item               | Migration note                                                                                                                                                                                                                                                                                                       |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                            |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                          |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                           |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                           |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                   |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Configurable HTTP Proxy listens on ports 8000 and 8001 by default; these are unprivileged. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                          |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                          |

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
