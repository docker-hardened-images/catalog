## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this opentelemetry-autoinstrumentation-java image

This Docker Hardened opentelemetry-autoinstrumentation-java image includes:

- The OpenTelemetry Java agent (`javaagent.jar`), built from source from the
  [opentelemetry-java-instrumentation](https://github.com/open-telemetry/opentelemetry-java-instrumentation) release
  tag.
- The agent at `/javaagent.jar`, the same path upstream publishes, so the OpenTelemetry Operator's injected copy command
  works unchanged.
- `cp`, which the operator needs in order to copy the agent out of this image and into the instrumented workload.

This image is a carrier for the agent jar. It does not contain a JVM — the agent runs inside your application's
container, not in this one.

## Run the container

The image has no entry point. Its default command is the same copy the OpenTelemetry Operator injects, so a manual run
only needs a volume mounted at `/otel-auto-instrumentation-java`:

```bash
docker run --rm -v otel-java-agent:/otel-auto-instrumentation-java dhi.io/opentelemetry-autoinstrumentation-java:<tag>
```

To pull the agent onto the host instead, override the destination:

```bash
docker run --rm -v "$(pwd):/out" dhi.io/opentelemetry-autoinstrumentation-java:<tag> cp /javaagent.jar /out/javaagent.jar
```

You can then attach it to any JVM:

```bash
java -javaagent:/path/to/javaagent.jar -jar myapp.jar
```

## Use with the OpenTelemetry Operator

Point the `java` image of an `Instrumentation` resource at this image. The operator injects it as an init container that
copies the agent into a shared volume, then sets `JAVA_TOOL_OPTIONS` on your application container:

```yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: java-instrumentation
spec:
  exporter:
    endpoint: http://otel-collector:4318
  java:
    image: dhi.io/opentelemetry-autoinstrumentation-java:<tag>
```

Annotate the workload you want instrumented:

```yaml
metadata:
  annotations:
    instrumentation.opentelemetry.io/inject-java: "true"
```

The agent is world-readable, so it can be copied by whichever user the operator's `securityContext` selects.

## Configure the agent

The agent is configured through environment variables on the *instrumented application* container, not on this image.
The most commonly used ones are below; see the
[agent configuration docs](https://opentelemetry.io/docs/zero-code/java/agent/configuration/) for the full set.

| Variable                      | Description                                   | Default                 |
| ----------------------------- | --------------------------------------------- | ----------------------- |
| `OTEL_SERVICE_NAME`           | Logical name of the instrumented service      | `unknown_service:java`  |
| `OTEL_EXPORTER_OTLP_ENDPOINT` | Endpoint the OTLP exporter sends telemetry to | `http://localhost:4318` |
| `OTEL_TRACES_EXPORTER`        | Trace exporter to use                         | `otlp`                  |
| `OTEL_JAVAAGENT_ENABLED`      | Set to `false` to disable the agent entirely  | `true`                  |

## FIPS variants

The `fips` tags carry OS-level FIPS posture and the STIG scan. This image performs no cryptography itself: the agent is
bytecode that the operator copies into your workload, and its crypto runs in that application's JVM through JCE. The
agent jar is identical in FIPS and non-FIPS tags, so use a FIPS-validated JVM in the instrumented application if you
need the agent's own operations covered.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

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
