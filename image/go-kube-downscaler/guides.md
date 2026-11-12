## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/go-kube-downscaler:1`
- Mirrored image: `<your-namespace>/dhi-go-kube-downscaler:1`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

GoKubeDownscaler is a Kubernetes controller that scales workloads down during a configured downtime window and restores
them when the window ends. This image is that controller. It is the catalog replacement for
`ghcr.io/caas-team/gokubedownscaler` on the 1.x line. Schedules and annotations are documented at
https://kube-downscaler.io/.

Debian 13 is the primary runtime tag: `dhi.io/go-kube-downscaler:1`. The same image is also published with the full
version tag of the current 1.x release. The Alpine 3.24 runtime tag is `dhi.io/go-kube-downscaler:1-alpine3.24`.

## Start a GoKubeDownscaler image

The entrypoint is `/app/gokubedownscaler`, a symlink to `/usr/bin/gokubedownscaler`. The image sets no command, no
application environment variables, and no health check. The working directory is `/`.

### Basic usage

`--help` exits 0 and writes usage to standard error. Standard output is empty. There is no version flag, and the binary
prints no version string. Flags use Go's `flag` package. The printed form is a single dash, for example `-once` and
`-metrics`.

```bash
docker run --rm dhi.io/go-kube-downscaler:1 --help
```

Runtime images run as user 65532 and contain no shell. `dhi.io/go-kube-downscaler:1` and
`dhi.io/go-kube-downscaler:1-alpine3.24` cannot run `bash` or `sh`. Dev tags run as root and include a shell.

### Ports

This image declares `8081/tcp` and `8085/tcp`. The upstream image does not expose those ports.

Port 8081 serves `/healthz` and `/readyz`. Those paths return HTTP 200 only after the process has created its Kubernetes
client. They are not a substitute for a successful scale.

Port 8085 serves Prometheus metrics. It listens only when you pass `-metrics`. The default is off.

### Run a downtime scan

A scan needs a kubeconfig via `-k`, or in-cluster configuration when the process runs inside the cluster. For a downtime
window that does not name a time zone, the process reads `DEFAULT_TIMEZONE` from the environment you pass at start (for
example `UTC`). This image does not set `DEFAULT_TIMEZONE`. Without a cluster the process exits non-zero.

- `-once` runs one scan and then exits. Without it, the process keeps scanning.
- `-k` selects a kubeconfig file instead of the in-cluster configuration.
- `-namespace` limits the scan to the namespaces you name. The default is every namespace.
- `-grace-period` sets the wait between workload creation and the first downscale. The usage text documents a 15-minute
  default.
- `-default-downtime` sets the timespans during which workloads are scaled down. Outside those timespans they are scaled
  up. The default is none.
- `-dry-run` prints the actions instead of applying them.

### Dev variants

Dev images run as root and include a shell and a package manager. `dhi.io/go-kube-downscaler:1-dev` is Debian 13 with
`bash` and `apt-get`. `dhi.io/go-kube-downscaler:1-alpine3.24-dev` is Alpine 3.24 with `bash` and `apk`.

```bash
docker run --rm --entrypoint bash dhi.io/go-kube-downscaler:1-dev -c 'command -v gokubedownscaler && gokubedownscaler --help >/tmp/h 2>&1 && grep -q -- -once /tmp/h'
```

```bash
docker run --rm --entrypoint bash dhi.io/go-kube-downscaler:1-alpine3.24-dev -c 'command -v gokubedownscaler && gokubedownscaler --help >/tmp/h 2>&1 && grep -q -- -once /tmp/h'
```

### Upstream Helm chart

The upstream chart installs `ghcr.io/caas-team/gokubedownscaler` and sets `podSecurityContext.runAsUser`, `runAsGroup`,
`fsGroup`, and `supplementalGroups` to 1000. This image runs as `nonroot`, uid 65532 and gid 65532. Pass these values so
the chart selects `dhi.io/go-kube-downscaler:1` and runs as 65532:65532. Leave `arguments`, `includedResources`,
`healthProbes`, and the container `securityContext` unset so the chart defaults stay in place. Those defaults keep the
chart's args and the `/healthz` and `/readyz` probes on port 8081.

```yaml
image:
  repository: dhi.io/go-kube-downscaler
  tag: "1"
podSecurityContext:
  runAsNonRoot: true
  runAsUser: 65532
  runAsGroup: 65532
  fsGroup: 65532
  supplementalGroups: [65532]
```

Use tag `1-alpine3.24` for the Alpine runtime image. Leave `webhookController.enabled` false. That deployment uses
`ghcr.io/caas-team/gokubedownscaler-webhook`, which this image does not supply.

## Non-hardened images vs. Docker Hardened Images

The upstream image is a scratch image. Its user is empty, so the process runs as root, and it has no shell. Runtime tags
of this image also have no shell, and they run as user 65532. A migration has to allow that user. Use a dev tag, or
Docker Debug, when you need a shell.

This image declares ports 8081 and 8085. The upstream image does not. Port 8085 stays closed unless the process is
started with `-metrics`.

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
