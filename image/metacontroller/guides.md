## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Metacontroller image

Metacontroller runs as an operator inside a Kubernetes cluster. It needs its CustomResourceDefinitions (CRDs) and RBAC
rules installed before it can reconcile anything.

### Check the binary and its flags

This command does not need a cluster. The image has no entrypoint, so the arguments replace the default command and must
include the binary path:

```console
$ docker run --rm dhi.io/metacontroller:4.17.7-alpine3.24 /usr/bin/metacontroller --help
```

The Debian 13 variants use the same tags with `debian13` in place of `alpine3.24`, for example
`dhi.io/metacontroller:4.17.7-debian13`.

### Install Metacontroller in a cluster

Use the upstream manifests for version 4.17.7 in
[manifests/production](https://github.com/metacontroller/metacontroller/tree/v4.17.7/manifests/production), with one
change: use this image instead of the upstream one.

1. Apply `metacontroller-crds-v1.yaml`, which defines the Metacontroller CRDs.
1. Apply `metacontroller-namespace.yaml` and `metacontroller-rbac.yaml`.
1. Apply `metacontroller.yaml`, a StatefulSet, after replacing `image: ghcr.io/metacontroller/metacontroller:v4.17.7`
   with `image: dhi.io/metacontroller:4.17.7-alpine3.24`.

Inside a cluster, Metacontroller uses the pod's service account. To run it outside a cluster, pass a kubeconfig with the
`-kubeconfig` flag or set the `KUBECONFIG` environment variable.

### Install with Helm

The upstream Helm chart is published as an OCI artifact. It installs the CRDs, RBAC, and the StatefulSet. Put the image
and the security context in a values file:

```yaml
image:
  repository: dhi.io/metacontroller
  tag: 4.17.7-alpine3.24
securityContext:
  runAsNonRoot: true
  runAsUser: 65532
  readOnlyRootFilesystem: true
  capabilities:
    drop:
      - ALL
```

Then install the chart with that file:

```console
$ helm install metacontroller oci://ghcr.io/metacontroller/metacontroller-helm --version 4.17.7 \
    --namespace metacontroller --create-namespace -f values.yaml
```

`runAsUser: 65532` is the numeric non-root user of the runtime image. The chart's default image tag is `v4.17.7`, which
this image does not publish, so set `image.tag` as shown. For the Debian 13 variant, use `4.17.7-debian13` as the tag.
The dev variants run as root, and `runAsNonRoot: true` rejects them, so use a runtime or FIPS tag with this security
context.

## Common Metacontroller use cases

### Composite controller

A `CompositeController` tells Metacontroller which parent resource to watch, which child resources to manage, and which
sync webhook to call. The example below is shortened from the image's lifecycle test. It manages one ConfigMap for each
`Widget`. The `Widget` CRD must already be installed; its group is `example.com` in this example.

```yaml
apiVersion: metacontroller.k8s.io/v1alpha1
kind: CompositeController
metadata:
  name: widget-controller
spec:
  generateSelector: true
  parentResource:
    apiVersion: example.com/v1alpha1
    resource: widgets
  childResources:
    - apiVersion: v1
      resource: configmaps
      updateStrategy:
        method: InPlace
  hooks:
    sync:
      webhook:
        url: http://widget-sync-hook.default.svc.cluster.local/sync
```

The image does not include a webhook. You provide one, in any language, that accepts the parent and its current children
as JSON and returns the desired children and status. Metacontroller sets owner references on the children it creates, so
deleting a `Widget` garbage-collects its ConfigMap. The
[Metacontroller documentation](https://metacontroller.github.io/metacontroller/) describes the webhook protocol.

### Health and metrics

The image listens on two ports:

- Port `8081` serves the health probe at `/readyz` (`-health-probe-bind-address`).
- Port `9999` serves Prometheus metrics at `/metrics` (`-metrics-address`).

## Non-hardened images vs. Docker Hardened Images

Compared with the upstream image `ghcr.io/metacontroller/metacontroller:v4.17.7`, these differences affect how you run
and troubleshoot the image:

- **No shell in runtime variants.** The upstream image includes `/bin/sh`. The runtime variants of this image do not, so
  `docker exec <container> /bin/sh` fails. To inspect a running container, use Docker Debug.
- **Numeric user.** The runtime variants run as UID and GID `65532` instead of the named `nonroot` user. Kubernetes
  cannot verify that a named user is non-root, so `runAsNonRoot: true` works with this image without further changes.

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
