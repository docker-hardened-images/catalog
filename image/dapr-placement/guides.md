## About the Dapr Placement Service

The dapr-placement is a Dapr control plane component that manages the distributed placement of actor instances across
your cluster. It uses the Raft consensus protocol to maintain cluster state and provides actor location services for
Dapr sidecars.

## Start a placement service

> **Note:** The dapr-placement image is primarily designed to run inside a Kubernetes cluster as part of a full Dapr
> control plane deployment. The standalone Docker command below displays the available configuration options.

Run the following command and replace `<tag>` with the image variant you want to run.

```console
$ docker run --rm dhi.io/dapr-placement:<tag> --help
```

## Deployment requirements

When deployed in Kubernetes, the placement service:

- Runs as a StatefulSet
- Requires ports 50005 (Raft consensus), 8080 (health checks), 9090 (metrics)
- Needs persistent storage for Raft logs
- Should be deployed with an odd number of replicas (3, 5, or 7) for proper Raft quorum

## Common configuration options

The placement service supports various command-line flags:

- `--log-level`: Set logging level (debug, info, warn, error, fatal)
- `--log-as-json`: Output logs in JSON format
- `--healthz-port`: Health check endpoint port (default: 8080)
- `--metrics-port`: Metrics endpoint port (default: 9090)
- `--port`: Raft consensus port (default: 50005)
- `--raft-log-store-path`: Path for Raft log storage

## Non-hardened images vs Docker Hardened Images

| Feature         | Non-hardened (daprio/placement) | Docker Hardened (dhi/dapr-placement)      |
| --------------- | ------------------------------- | ----------------------------------------- |
| Base image      | Debian Slim                     | Debian 13 hardened base                   |
| User            | Root by default                 | Nonroot user (UID 65532)                  |
| Binary location | `/placement`                    | `/usr/local/bin/placement`                |
| Shell/utilities | Included                        | Not included (minimal attack surface)     |
| CVE compliance  | Standard patching               | Near-zero CVEs with proactive remediation |
| Provenance      | Not signed                      | Signed with complete SBOM/VEX             |

Docker Hardened Images prioritize security through minimalism. Runtime images contain no shell or package manager. Use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) for troubleshooting.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                 |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                    |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                        |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                               |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                               |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   If you're using a multi-stage build, update the runtime stage to use a non-dev hardened image. This ensures your
   production containers run with minimal attack surface.

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
