## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Tags

Each tag names a version, an optional distribution, and an optional variant suffix:

- Version: `0.66b2` (the OpenTelemetry Python distribution version), `0.66`, or `0` (Debian only).
- Distribution: `-debian13` or `-alpine3.24`. Tags without a distribution suffix refer to Debian 13.
- Variant: `-dev` for build-time variants, `-fips` for FIPS variants, or `-fips-dev` for both.

Examples:

- Debian 13 runtime: `0.66b2`, `0.66b2-debian13`, `0.66`, `0`
- Alpine 3.24 runtime: `0.66b2-alpine3.24`, `0.66-alpine3.24`, `0-alpine3.24`
- Build-time variants: `0.66b2-dev`, `0.66b2-alpine3.24-dev`
- FIPS variants: `0.66b2-fips`, `0.66b2-fips-dev`, `0.66b2-alpine3.24-fips`

## Start an OpenTelemetry Python Autoinstrumentation image

The image has no entrypoint. Its default command copies the instrumentation bundle from `/autoinstrumentation` into
`/otel-auto-instrumentation-python`. This is the same copy that the OpenTelemetry Operator runs in its init container.
The image is a copy job, not a server: the container exits when the copy finishes.

Run the image with a named volume to populate the volume with the bundle:

```bash
docker run --rm -v otel-python-autoinstrumentation:/otel-auto-instrumentation-python \
  dhi.io/opentelemetry-autoinstrumentation-python:<tag>
```

List the launchers in the volume with a second container. The runtime image includes `ls`, so override the entrypoint:

```bash
docker run --rm --entrypoint ls -v otel-python-autoinstrumentation:/otel-auto-instrumentation-python \
  dhi.io/opentelemetry-autoinstrumentation-python:<tag> -l /otel-auto-instrumentation-python/bin
```

To copy the bundle onto the host instead, create a container without starting it and copy from it:

```bash
cid=$(docker create dhi.io/opentelemetry-autoinstrumentation-python:<tag>)
docker cp "$cid:/autoinstrumentation/." ./otel-python-autoinstrumentation
docker rm "$cid"
```

The source path ends in `/.` so that `docker cp` copies the directory contents and not the symlink. See the note on
copying in [Copy the bundle in a custom init container](#copy-the-bundle-in-a-custom-init-container).

## Common OpenTelemetry Python Autoinstrumentation use cases

### Inject the bundle with the OpenTelemetry Operator

The OpenTelemetry Operator injects this image as an init container. The init container copies the bundle into a shared
volume that your application container uses. Point the `python` image of an `Instrumentation` resource at this image:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: python-instrumentation
spec:
  exporter:
    endpoint: http://otel-collector:4318
  python:
    image: dhi.io/opentelemetry-autoinstrumentation-python:0.66b2
```

Annotate the workload that you want instrumented:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-python: "true"
```

The Operator's default copy command for glibc workloads is the same copy as the default command of this image, so no
command override is needed.

### Use the musl tree for Alpine workloads

For application containers based on musl (Alpine), add the `otel-python-platform` annotation. The Operator then copies
the bundle from `/autoinstrumentation-musl` instead of `/autoinstrumentation`:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-python: "true"
    instrumentation.opentelemetry.io/otel-python-platform: musl
```

Both the glibc and the musl trees ship in the Debian and the Alpine images of this product. Use the glibc tree for
Debian application images and the musl tree for Alpine application images.

### Run as a numeric nonroot user in Kubernetes

The runtime and FIPS variants run as the numeric user `65532`. A pod with `runAsNonRoot: true` and no `runAsUser` admits
this image, but the same pod refuses upstream's image, which runs as root. Set numeric IDs in the pod security context:

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65532
    fsGroup: 65532
```

Set `fsGroup: 65532` when the Operator writes the bundle to a persistent volume claim
(`spec.python.volumeClaimTemplate`). An ephemeral volume of this kind is owned by `root:root` with mode `0755`, and the
copy runs as `65532`, so the copy fails unless the volume is group-writable for `65532`.

### Copy the bundle in a custom init container

The Debian 13 runtime variant has no shell, so an init container that runs `sh -c` fails there. The Alpine 3.24 runtime
variant includes BusyBox `/bin/sh`, so the same command runs there as uid `65532`. If you need a shell on either distro,
use the `-dev` variant. Dev variants run as root and include a shell.

```yaml
initContainers:
  - name: copy-python-autoinstrumentation
    image: dhi.io/opentelemetry-autoinstrumentation-python:0.66b2-dev
    command: ["sh", "-c", "cp -r /autoinstrumentation/. /otel-auto-instrumentation-python"]
    volumeMounts:
      - name: otel-auto-instrumentation-python
        mountPath: /otel-auto-instrumentation-python
```

Use the `/.` suffix on the source path. `/autoinstrumentation` is a relative symlink to the glibc tree. Copying the path
without the suffix (`cp -r /autoinstrumentation dst`) copies the symlink itself, and the relative target does not
resolve in the destination. `cp -rL /autoinstrumentation dst` also copies the tree.

## FIPS variants and the instrumented application

The `-fips` and `-fips-dev` variants include the OpenSSL FIPS provider. The Python interpreter in the image uses that
OpenSSL: in the FIPS variants the interpreter runs in OpenSSL FIPS mode, and a `hashlib.md5()` call fails. The variants
set `OPENSSL_CONF`, `OPENSSL_MODULES`, and `SSL_CERT_FILE` to point at the FIPS configuration.

The FIPS claim covers the Python interpreter bundled in the image and the operating-system posture of this image. It
does not change the cryptography of the application that you instrument. The bundle runs inside the workload's own
Python interpreter and OpenSSL. If the cryptographic operations of your application must be FIPS validated, run that
application on a FIPS-validated interpreter and OpenSSL.

## Non-hardened images vs. Docker Hardened Images

The upstream `otel/autoinstrumentation-python` image differs from this image in these ways that matter when you copy the
bundle:

- **User:** upstream runs as root. The runtime and FIPS variants run as the numeric user `65532`. Use numeric IDs in pod
  security contexts (see [Run as a numeric nonroot user in Kubernetes](#run-as-a-numeric-nonroot-user-in-kubernetes)).
- **Shell:** upstream's default command is `sh`, and its image includes `/bin/sh`. The Debian 13 runtime variant has no
  shell. The Alpine 3.24 runtime variant includes BusyBox `/bin/sh`, which its `coreutils` package pulls in and apk
  cannot exclude. Use a `-dev` variant for init containers that need a shell on either distro.
- **Default command:** upstream's default command is `sh`. This image's default command copies the bundle into
  `/otel-auto-instrumentation-python`, which upstream does not provide. The directory is owned by `65532`.
- **Symlinks:** `/autoinstrumentation` and `/autoinstrumentation-musl` are relative symlinks to the trees under
  `/usr/lib/opentelemetry-autoinstrumentation-python/`. In upstream these paths are directories. Copy with the `/.`
  suffix (see [Copy the bundle in a custom init container](#copy-the-bundle-in-a-custom-init-container)).
- **Interpreter:** this image adds Python 3.15 at `/usr/bin/python3.15`. The launchers in the bundle use that path in
  their shebang. Upstream does not include an interpreter at that path.

This image has no entrypoint, the same as upstream.

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

For this image, the Debian 13 runtime variant has no shell. The Alpine 3.24 runtime variant includes BusyBox `/bin/sh`
(see [Non-hardened images vs. Docker Hardened Images](#non-hardened-images-vs-docker-hardened-images)).

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
