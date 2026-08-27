## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/tempo-query:<tag>`
- Mirrored image: `<your-namespace>/dhi-tempo-query:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Tempo Query image

This Docker Hardened Image ships the `tempo-query` binary (`/opt/tempo-query/tempo-query`), which speaks the Jaeger
storage plugin gRPC protocol on port **7777** by default and forwards queries to your Tempo HTTP API. Configuration
options are covered in the [Grafana Tempo documentation](https://grafana.com/docs/tempo/latest/configuration/)⁠.

## Start Tempo Query

The process listens on **0.0.0.0:7777** unless you change it. Point `backend` at your Tempo HTTP base URL (for example
`http://tempo:3200`). You can pass a YAML config file with `-config` or set the same keys via environment variables
(Viper-style, e.g. `BACKEND=http://tempo:3200`).

```console
$ docker run --rm -p 7777:7777 \
  -e BACKEND=http://tempo:3200 \
  dhi.io/tempo-query:2
```

See the upstream [Tempo configuration reference](https://grafana.com/docs/tempo/latest/configuration/)⁠ for TLS, tenant
headers, and related settings.

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Feature             | DOI (`grafana/tempo-query`) | DHI (`dhi.io/tempo-query`)                |
| ------------------- | --------------------------- | ----------------------------------------- |
| User                | `10001:10001` (numeric UID) | `nonroot` (runtime/FIPS)                  |
| Shell               | No                          | No (runtime/FIPS)                         |
| Package manager     | No                          | No (runtime/FIPS)                         |
| Binary path         | `/tempo-query`              | `/opt/tempo-query/tempo-query`            |
| Entrypoint          | ENTRYPOINT `/tempo-query`   | ENTRYPOINT `/opt/tempo-query/tempo-query` |
| Default listen addr | `0.0.0.0:7777`              | `0.0.0.0:7777`                            |
| Zero CVE commitment | No                          | Yes                                       |
| FIPS variant        | No                          | Yes (FIPS + STIG + CIS)                   |
| Base OS             | Distroless (no OS labels)   | Docker Hardened Images (Debian 13)        |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

**Runtime variants** are designed to run Tempo Query in production. These images typically:

- Run as a nonroot user
- Do not include a shell or a package manager
- Contain only the `tempo-query` binary and TLS certificates
- Include CIS benchmark compliance (`com.docker.dhi.compliance: cis`)

**Dev variants** include `dev` in the tag (for example, `2-dev`). They are intended for multi-stage Dockerfiles or
interactive troubleshooting. These images typically:

- Run as root
- Include a shell and Debian package manager (`apt`)
- Ship the same `tempo-query` binary as the runtime image

**FIPS variants** include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

For debugging minimal runtime containers without a shell, you can use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to running containers.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or Kubernetes manifests. At
minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This and a few other
common changes are listed in the following table of migration notes:

| Item               | Migration note                                                                                                                                                              |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile or Kubernetes manifests with a Docker Hardened Image.                                                                           |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                   |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                  |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                      |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                          |
| Ports              | Tempo Query listens on port 7777 by default (above 1024), so no privileged port issues arise.                                                                               |
| Entry point        | Docker Hardened Images may have different entry points than upstream images. Inspect entry points for Docker Hardened Images and update your deployment if necessary.       |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. |

The following steps outline the general migration process.

1. **Find hardened images for your app.** The Tempo Query hardened image may have several variants. Inspect the image
   tags and find the image variant that meets your needs.
1. **Update the image references in your Kubernetes manifests or Compose files.** Point the Tempo Query sidecar or
   deployment at `dhi.io/tempo-query` with the appropriate tag.
1. **For custom deployments, update the runtime image in your Dockerfile.** If you're building custom images based on
   Tempo Query, ensure that your final image uses the hardened image as the base.
1. **Verify connectivity to Tempo.** Ensure the `backend` URL (or equivalent config) is reachable from the Tempo Query
   container.

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than upstream Tempo Query images. Use `docker inspect` to inspect
entry points for Docker Hardened Images and update your Kubernetes deployment if necessary.
