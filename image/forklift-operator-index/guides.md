## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this forklift-operator-index image

This Docker Hardened forklift-operator-index image is an
[Operator Lifecycle Manager (OLM)](https://olm.operatorframework.io/) File-Based Catalog (FBC) index for the Forklift
operator, the upstream project behind Red Hat Migration Toolkit for Virtualization (MTV). It includes:

- `opm`: The Operator Package Manager CLI (image entrypoint) that manages and serves File-Based Catalog content over
  gRPC.
- `grpc_health_probe`: A CLI for probing gRPC health endpoints (for example, Kubernetes/OLM liveness and readiness
  checks).
- The [mtv-fbc](https://github.com/kubev2v/mtv-fbc) File-Based Catalog for OpenShift `v4.22`, staged at `/configs`. The
  catalog defines the `mtv-operator` package's `release-v2.11` and `release-v2.12` channels and their bundles.

The `opm serve` cache is pre-populated at `/tmp/cache` at build time, mirroring the upstream `catalog.Dockerfile`
pattern (`opm serve /configs --cache-dir=/tmp/cache --cache-only`), so the container starts serving immediately without
regenerating the cache on every boot.

The default entrypoint is `/bin/opm` with the default command `serve /configs --cache-dir=/tmp/cache`, which serves the
catalog over gRPC on port `50051`. The image also carries the label
`operators.operatorframework.io.index.configs.v1=/configs` so OLM tooling can locate the catalog root.

### Run the forklift-operator-index container

Start the catalog index and serve it over gRPC:

```console
$ docker run -d --name forklift-operator-index -p 50051:50051 \
  dhi.io/forklift-operator-index:<tag>
```

Display `opm` version information (overrides the default `cmd`, entrypoint stays `/bin/opm`):

```console
$ docker run --rm dhi.io/forklift-operator-index:<tag> version
```

Render the staged catalog to inspect its contents:

```console
$ docker run --rm dhi.io/forklift-operator-index:<tag> render /configs
```

Check gRPC health from inside a running container:

```console
$ docker exec forklift-operator-index /bin/grpc_health_probe -addr=localhost:50051
```

### Use the index as an OLM CatalogSource

The typical way to consume this image is as the `image` of an OLM `CatalogSource` on OpenShift, OKD, or any cluster
running the Operator Lifecycle Manager:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: forklift-operator-index
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: dhi.io/forklift-operator-index:<tag>
  displayName: Forklift Operator Index
  publisher: Konveyor
```

```console
$ kubectl apply -f catalogsource.yaml
$ kubectl get catalogsource -n openshift-marketplace forklift-operator-index
```

Once OLM reports the `CatalogSource` as `READY`, the `mtv-operator` package and its `release-v2.11`/`release-v2.12`
channels become available for subscription. Installing the operator itself pulls images from
`registry.redhat.io/migration-toolkit-virtualization`, which may require Red Hat entitlement on the cluster.

### Layer your own catalog content

Because runtime images have no shell, extend this image with the exec form of `RUN` and regenerate the cache with `opm`
rather than a shell script:

```dockerfile
FROM dhi.io/forklift-operator-index:<tag>
COPY --chown=65532:65532 my-catalog/ /configs/
RUN ["/bin/opm", "serve", "/configs", "--cache-dir=/tmp/cache", "--cache-only"]
```

This replaces the shipped `mtv-fbc` catalog with your own File-Based Catalog while keeping the same entrypoint, labels,
and gRPC serving behavior.

> **Note:** This image runs as the nonroot user (uid `65532`) by default. The upstream `forklift-operator-index` image
> runs as uid `1001`. If you deploy manifests that pin `runAsUser: 1001` or rely on file ownership matching that uid,
> update them to match uid `65532`, or use a `-dev` variant (which runs as root) for build stages that need to write to
> `/configs` before switching back to a nonroot runtime stage.

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
debugging applications built with Docker Hardened Images is to use [Docker Debug](/reference/cli/docker/debug/) to
attach to these containers. Docker Debug provides a shell, common debugging tools, and lets you install other tools in
an ephemeral, writable layer that only exists during the debugging session.

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
