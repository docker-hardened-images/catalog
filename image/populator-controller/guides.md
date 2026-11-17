## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/populator-controller:<tag>`
- Mirrored image: `<your-namespace>/dhi-populator-controller:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a populator-controller image

The populator controller is a Kubernetes controller. It reads its cluster credentials from the pod service account, so
it is normally deployed by the Forklift operator rather than run standalone. Running it locally is still useful to
confirm the image and inspect the available flags:

```bash
$ docker run --rm dhi.io/populator-controller:<tag> --help
```

Outside a cluster the controller does not do useful work, and it does not exit on its own:

- With no populator image variable set, it logs a warning for each migration source it is skipping and then blocks
  indefinitely without starting any reconciler. Stop it with `docker stop`, or run it with `--rm -it` so you can
  interrupt it.
- Once a populator image variable is set, it starts that reconciler, fails to build a cluster configuration, and exits
  with a fatal `Failed to create config` message.

Both behaviors match the upstream image and are expected outside a cluster.

### Select which migration sources to reconcile

The controller starts one reconciler per source, and only for sources whose populator image variable is set. Any source
whose variable is missing is skipped with a warning at startup.

| Variable                               | Description                                                       | Required |
| -------------------------------------- | ----------------------------------------------------------------- | -------- |
| `OVIRT_POPULATOR_IMAGE`                | Image used for oVirt disk transfers; enables the oVirt reconciler | No       |
| `OPENSTACK_POPULATOR_IMAGE`            | Image used for OpenStack image transfers; enables that reconciler | No       |
| `VSPHERE_COPY_OFFLOAD_POPULATOR_IMAGE` | Image used for vSphere copy offload; enables that reconciler      | No       |
| `MAX_POPULATOR_INFLIGHT`               | Maximum concurrent populator pods per host (default `20`)         | No       |

Each active reconciler serves Prometheus metrics on its own port: oVirt on `8080`, OpenStack on `8081`, and vSphere copy
offload on `8082`. The metrics path defaults to `/metrics` and can be changed with `--metrics-path`.

The controller also reads the following variables to size the populator pods it creates:
`POPULATOR_CONTAINER_LIMITS_CPU`, `POPULATOR_CONTAINER_LIMITS_MEMORY`, `POPULATOR_CONTAINER_REQUESTS_CPU`, and
`POPULATOR_CONTAINER_REQUESTS_MEMORY`.

### Run in a cluster

In a cluster, give the pod a service account that can read PersistentVolumeClaims, PersistentVolumes, Pods, and
StorageClasses, and can watch and update the Forklift volume populator custom resources. The controller then creates a
`prime-<pvc-uid>` PersistentVolumeClaim and a `populate-<pvc-uid>` pod for each PersistentVolumeClaim whose
`dataSourceRef` points at one of those custom resources.

Note that a StorageClass using `WaitForFirstConsumer` binding causes the controller to wait until a node is selected
before creating the populator pod. This is upstream behavior and applies equally to the non-hardened image.

## Non-hardened images vs. Docker Hardened Images

The entry point, command, and working directory match the upstream image, so swapping the image reference is the only
change a Forklift deployment needs. Two differences are worth knowing about first.

### FIPS

Upstream builds its default image with the `strictfipsruntime` build tag and `GOEXPERIMENT=strictfipsruntime`. The
runtime variant of this hardened image uses standard Go cryptography instead, so replacing the upstream image with a
non-FIPS tag changes the controller's cryptographic posture. If you rely on the upstream FIPS build, use a tag with the
`-fips` suffix.

### Nonroot user

The upstream image runs as root. The runtime variant of this hardened image runs as the nonroot user, and the controller
still works unchanged: it writes no files, and its metrics listeners bind ports 8080, 8081, and 8082, all above the
privileged range. The Forklift operator's populator controller Deployment sets no `securityContext`, so no manifest
change is required to accommodate the different user.

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
