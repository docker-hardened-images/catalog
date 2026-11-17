## How to use this image

## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/k8s-driver-manager:<version>`
- Mirrored image: `<your-namespace>/dhi-k8s-driver-manager:<version>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this K8s Driver Manager image

This Docker Hardened Image ships the `driver-manager` binary (`/usr/bin/driver-manager`) and the `vfio-manage` binary
(`/usr/bin/vfio-manage`). No ports are exposed.

### Root and privileged requirement

Unlike most Docker Hardened Images, this image's runtime, dev, and FIPS variants all run as root (`0:0`), and its
runtime variants ship a minimal shell (`dash`/`coreutils` on Debian, `busybox` on Alpine). This is an intentional,
upstream-driven exception, not a hardening gap:

- `driver-manager` and `vfio-manage` `chroot` into the host's mounted root filesystem to run `modprobe` and
  `nvidia-smi`, and `driver-manager` calls `mount.RecursiveUnmount` on the host mount namespace to safely unmount driver
  filesystems during an uninstall. None of this is possible as a non-root, capability-restricted user.
- The NVIDIA GPU Operator's own `nvidia-vfio-manager` DaemonSet runs this image's container as
  `command: ["/bin/sh", "-c"], args: ["vfio-manage bind --all && while true; do sleep 86400; done"]`, with a `preStop`
  hook of `/bin/sh -c "vfio-manage unbind --all"` - a real, documented deployment pattern that requires a POSIX shell in
  the image.

Deployments of this image should run with `securityContext.privileged: true` (matching the GPU Operator's own
manifests), not merely `runAsUser: 0`.

## Start K8s Driver Manager

This image is not typically run standalone with `docker run` - it is invoked by the NVIDIA GPU Operator as a Kubernetes
init container (`driver-manager preflight_check` / `driver-manager uninstall_driver`) and, for VFIO passthrough nodes,
as a long-running sidecar (`vfio-manage bind` / `vfio-manage unbind`). To confirm the image and binaries:

```console
$ docker run --rm --entrypoint driver-manager dhi.io/k8s-driver-manager:<version> --version
$ docker run --rm --entrypoint vfio-manage dhi.io/k8s-driver-manager:<version> --version
```

Replace `<version>` with the desired version.

### Deploy through the NVIDIA GPU Operator

The GPU Operator pulls this image itself. Point its `driver.manager` values at the hardened image when installing or
upgrading the chart:

```console
$ helm upgrade --install gpu-operator nvidia/gpu-operator \
  --namespace gpu-operator --create-namespace \
  --set driver.manager.repository=dhi.io \
  --set driver.manager.image=k8s-driver-manager \
  --set driver.manager.version=<version>
```

The operator injects the image as the `k8s-driver-manager` init container of the `nvidia-driver-daemonset`. Verify the
running pods picked it up:

```console
$ kubectl -n gpu-operator get daemonset nvidia-driver-daemonset \
  -o jsonpath='{.spec.template.spec.initContainers[?(@.name=="k8s-driver-manager")].image}'
```

## Non-hardened images vs Docker Hardened Images

| Feature             | Non-hardened (`nvcr.io/.../k8s-driver-manager`)   | Docker Hardened (`dhi.io/k8s-driver-manager`)     |
| ------------------- | ------------------------------------------------- | ------------------------------------------------- |
| User                | root (0:0)                                        | root (0:0) - required on every variant            |
| Shell               | Yes (`/bin/sh`, busybox-derived)                  | Yes (`dash`/`busybox`) - required, see above      |
| Package manager     | No                                                | No (runtime/FIPS); `apt`/`apk` on `-dev`          |
| Binary paths        | `/usr/bin/driver-manager`, `/usr/bin/vfio-manage` | `/usr/bin/driver-manager`, `/usr/bin/vfio-manage` |
| Entrypoint          | `driver-manager preflight_check`                  | `driver-manager preflight_check`                  |
| Zero CVE commitment | No                                                | Yes                                               |
| FIPS variant        | No                                                | Yes (FIPS + STIG)                                 |
| Base OS             | `distroless/cc`                                   | Docker Hardened Images (Debian 13 / Alpine 3.24)  |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  **`k8s-driver-manager` is an exception to the first two points above:** `driver-manager` chroots into the host root to
  run `modprobe` and `nvidia-smi` and unmounts host driver filesystems, so this image runs as root, and the GPU Operator
  invokes `vfio-manage` through `/bin/sh -c`, so it includes a minimal shell. It still has no package manager.

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

| Item               | Migration note                                                                                                                                                                                                                                                                                                                                                                                                                               |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user. **`k8s-driver-manager` is an exception:** it runs as root on every variant, matching upstream. Keep `securityContext.privileged: true` as the GPU Operator's own manifests do.                                                                                                    |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. **`k8s-driver-manager` is an exception:** it exposes no ports and runs as root, so neither restriction applies. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. **`k8s-driver-manager` is an exception:** it ships a minimal shell on every variant, because the GPU Operator invokes `vfio-manage` through `/bin/sh -c`.                                                                                                        |

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
during the debugging session. **`k8s-driver-manager` is an exception:** it ships a minimal shell, so `kubectl exec` and
`docker exec` work directly. Use a `dev` variant or Docker Debug when you need a package manager.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them. **`k8s-driver-manager` is an exception:** it runs as root, so
ownership is not usually the issue. Check instead that the host paths it needs, such as the mounted host root
filesystem, are present and writable.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81. **`k8s-driver-manager` is an
exception:** it exposes no ports and runs as root, so neither restriction applies.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell. **`k8s-driver-manager` is an exception:** it ships a minimal shell (`dash` on Debian, `busybox` on
Alpine) on every variant, because the GPU Operator invokes `vfio-manage` through `/bin/sh -c`.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
