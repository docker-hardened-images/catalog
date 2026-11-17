## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this opentelemetry-autoinstrumentation-dotnet image

This Docker Hardened opentelemetry-autoinstrumentation-dotnet image includes:

- The OpenTelemetry .NET Automatic Instrumentation payload, built from upstream's pinned release archives for the glibc
  and musl Linux profilers, with its managed startup hook and SDK assemblies. Upstream's files are unchanged apart from
  two added license notices (`miniutf-LICENSE.txt` and `spdlog-LICENSE.txt`).
- The payload at `/autoinstrumentation`, the same path upstream publishes, so the OpenTelemetry Operator's injected copy
  command and `COPY --from` references work unchanged. The payload itself is installed at
  `/usr/lib/opentelemetry-dotnet-instrumentation`.
- `cp`, which the operator needs in order to copy the payload out of this image and into the instrumented workload. On
  Alpine tags `cp` comes from BusyBox, which also provides `/bin/sh`. The Debian runtime tags have coreutils `cp` and no
  shell.

This image is a carrier for the payload. It does not contain a .NET runtime. The profiler runs inside your application's
container, not in this one.

## Run the container

The image has no entry point. Its default command is the same copy the OpenTelemetry Operator injects, so a manual run
only needs a volume mounted at `/otel-auto-instrumentation-dotnet`:

```bash
docker run --rm -v otel-dotnet-agent:/otel-auto-instrumentation-dotnet dhi.io/opentelemetry-autoinstrumentation-dotnet:<tag>
```

To copy the payload onto the host instead, create the destination directory first and run the copy as your host user.
The image's default user, `65532`, cannot write to a directory that your host user owns:

```bash
mkdir otel-dotnet-agent
docker run --rm --user "$(id -u):$(id -g)" -v "$(pwd)/otel-dotnet-agent:/out" dhi.io/opentelemetry-autoinstrumentation-dotnet:<tag> cp -r /autoinstrumentation/. /out
```

Alternatively, create a container from the image without starting it, copy the payload out with `docker cp`, and remove
the container. `/autoinstrumentation` is a symlink to the payload directory, so use `-L` to follow it. Without `-L`,
only the link is copied, and it does not resolve on the host:

```bash
docker create --name otel-dotnet-agent-src dhi.io/opentelemetry-autoinstrumentation-dotnet:<tag>
docker cp -L otel-dotnet-agent-src:/autoinstrumentation ./otel-dotnet-agent
docker rm otel-dotnet-agent-src
```

## Load the profiler into a .NET application

Copy the payload into your application image with a multi-stage build, then set the profiler environment variables on
the application. Use the glibc profiler for Debian, Ubuntu and other glibc-based application images, and the musl
profiler for Alpine application images.

```dockerfile
FROM dhi.io/opentelemetry-autoinstrumentation-dotnet:<tag> AS otel
FROM dhi.io/dotnet:<tag>
COPY --from=otel /autoinstrumentation /otel-auto-instrumentation-dotnet
ENV CORECLR_ENABLE_PROFILING=1 \
    CORECLR_PROFILER={918728DD-259F-4A6A-AC2B-B85E1B658318} \
    CORECLR_PROFILER_PATH=/otel-auto-instrumentation-dotnet/linux-x64/OpenTelemetry.AutoInstrumentation.Native.so \
    DOTNET_STARTUP_HOOKS=/otel-auto-instrumentation-dotnet/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll \
    OTEL_DOTNET_AUTO_HOME=/otel-auto-instrumentation-dotnet
```

Use `linux-musl-x64/` in `CORECLR_PROFILER_PATH` on Alpine application images. On arm64 hosts, use `linux-arm64/` or
`linux-musl-arm64/`.

## Use with the OpenTelemetry Operator

Point the `dotnet` image of an `Instrumentation` resource at this image. The operator injects it as an init container
that copies the payload into a shared volume, then sets the profiler variables on your application container:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: dotnet-instrumentation
spec:
  exporter:
    endpoint: http://otel-collector:4318
  dotnet:
    image: dhi.io/opentelemetry-autoinstrumentation-dotnet:<tag>
```

Annotate the workload you want instrumented:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-dotnet: "true"
```

For an Alpine application image, select the musl profiler with an additional annotation:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/otel-dotnet-auto-runtime: linux-musl-x64
```

### Security context for the init container

With no security context set, the init container runs as the image's default user, `65532`. The payload is
world-readable, and the default copy target is owned by `65532`, so the copy works into an `emptyDir` and into a fresh
named volume. A root-owned directory that `65532` cannot write rejects the copy.

The Operator chooses the init container's security context in this order:

1. `spec.initContainerSecurityContext` on the `Instrumentation` resource, if set.
1. Otherwise, the security context of the first instrumented application container. An application `runAsUser` therefore
   also becomes the init container's user.
1. Only when neither is set, the image's default user, `65532`.

Set the init container's context on the `Instrumentation` resource, next to `spec.dotnet`:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: dotnet-instrumentation
spec:
  exporter:
    endpoint: http://otel-collector:4318
  dotnet:
    image: dhi.io/opentelemetry-autoinstrumentation-dotnet:<tag>
  initContainerSecurityContext:
    runAsUser: 65532
    runAsGroup: 65532
    runAsNonRoot: true
```

`fsGroup` is a Pod-level setting. Put it under the workload's Pod `securityContext`, not on the `Instrumentation`
resource. It gives the Pod's volumes a group the init container can write through:

```yaml
spec:
  template:
    spec:
      securityContext:
        fsGroup: 65532
```

## Configure the profiler

The profiler is configured through environment variables on the *instrumented application* container, not on this image.
The most commonly used ones are below; see the
[agent configuration docs](https://opentelemetry.io/docs/zero-code/dotnet/configuration/) for the full set.

| Variable                             | Description                                            |
| ------------------------------------ | ------------------------------------------------------ |
| `OTEL_SERVICE_NAME`                  | Logical name of the instrumented service               |
| `OTEL_EXPORTER_OTLP_ENDPOINT`        | Endpoint the OTLP exporter sends telemetry to          |
| `OTEL_TRACES_EXPORTER`               | Trace exporter to use                                  |
| `OTEL_DOTNET_AUTO_FAIL_FAST_ENABLED` | Exit the application when the profiler fails to attach |

Upstream documents the defaults for each variable.

## FIPS variants

The `fips` tags carry OS-level FIPS posture and the STIG scan. This image performs no cryptography itself: the profiler
and managed startup hook are loaded into your application, and their TLS (OTLP over HTTPS) runs in that application's
.NET runtime, using the application image's OpenSSL. The payload is identical in FIPS and non-FIPS tags. To have the
instrumentation's own TLS operations covered, run the instrumented application on a FIPS .NET image, such as a DHI
`-fips` .NET tag.

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
