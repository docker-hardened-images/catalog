## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use, replace the image
reference with your mirrored location.

For example:

- Public image: `dhi.io/cephcsi:<tag>`
- Mirrored image: `<your-namespace>/dhi-cephcsi:<tag>`

Authenticate first with `docker login dhi.io` before pulling the image.

## What's included in this cephcsi image

This Docker Hardened Image includes:

- `cephcsi` for the CSI controller and node services
- `ceph` and `rbd` for Ceph cluster and block operations
- `ceph-fuse` for CephFS userspace mounts
- Runtime mount and filesystem helpers required by the node plugin
- The minimal shell and Python runtime needed for the upstream `ceph` CLI wrapper

## Start a cephcsi image

To inspect the packaged driver version:

```bash
docker run --rm dhi.io/cephcsi:<tag> --version
```

## Deploy in Kubernetes

Ceph CSI is typically deployed through the upstream manifests or Helm charts from the `ceph/ceph-csi` project. When
migrating to Docker Hardened Images, replace the upstream image reference `quay.io/cephcsi/cephcsi:<tag>` with
`dhi.io/cephcsi:<tag>` in the controller and node workloads.

The hardened runtime image defaults to a non-root user. Controller deployments usually only need the image reference
swap, but nodeplugin deployments may also need an explicit Kubernetes `securityContext` override so the container runs
as `root` for host mount, device, and filesystem operations.

## Runtime requirements

The controller and node services share the same image, but the node plugin has stricter runtime requirements:

- The hardened image defaults to non-root, but node plugin deployments may need an explicit `securityContext` override
  to run the container as `root`.
- Running the node plugin as `root` is required for host mount operations, filesystem formatting, and kernel module
  interactions.
- It typically needs privileged Kubernetes settings, host access to `/dev`, and mount propagation into
  `/var/lib/kubelet`.
- CephFS support can use `ceph-fuse` when the kernel client helper is unavailable.

### Hardened image debugging

This runtime image includes a minimal shell only because the upstream `ceph` CLI wrapper requires `/bin/sh`. It should
not be treated as a general-purpose debugging environment, and the image still omits the usual interactive debugging
tool set. Common debugging methods for applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug dhi.io/cephcsi:<tag>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/cephcsi:<tag> /dbg/bin/sh
```

### Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager, except where an upstream runtime contract requires a minimal shell
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
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. This image is an exception because the upstream `ceph` CLI wrapper requires `/bin/sh`. Use dev images in build stages for general shell-based build steps.                                                                                          |

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

By default, image variants intended for runtime don't contain a shell. This image includes a minimal `/bin/sh` only to
support the upstream `ceph` CLI wrapper and should not be treated like a dev image. Use `dev` images in build stages to
run shell commands and use Docker Debug for interactive troubleshooting.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
