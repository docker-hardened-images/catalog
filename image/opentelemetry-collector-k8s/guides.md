## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This guide shows how to run the OpenTelemetry Collector Kubernetes distribution (`otelcol-k8s`) Hardened Image. For the
full list of receivers, processors and exporters, and for configuration reference, see the
[OpenTelemetry Collector documentation](https://opentelemetry.io/docs/collector/).

## What's included in this OpenTelemetry Collector Kubernetes image

This Docker Hardened OpenTelemetry Collector Kubernetes image includes:

- The `otelcol-k8s` binary, built from the official OpenTelemetry Collector releases. The entrypoint is `/otelcol-k8s`.
- The Kubernetes receivers, processors and extensions of the distribution, such as `k8s_cluster`, `k8s_events`,
  `k8s_objects`, `kubelet_stats`, `k8s_attributes` and `k8s_observer`. Run the `components` subcommand to list every
  component.
- No default configuration, as in the upstream image. You must pass `--config`.

## Start an OpenTelemetry Collector Kubernetes image

Create `config.yaml`. This example accepts OTLP over HTTP and prints what it receives:

```bash
cat <<EOF > config.yaml
receivers:
  otlp:
    protocols:
      http:
        endpoint: 0.0.0.0:4318
processors:
  batch:
exporters:
  debug:
    verbosity: detailed
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [debug]
EOF
```

Run the collector with the configuration mounted:

```bash
docker run -d --name otelcol-k8s \
    -p 4318:4318 \
    -v "$PWD/config.yaml:/etc/otelcol-k8s/config.yaml:ro" \
    dhi.io/opentelemetry-collector-k8s:<tag> \
    --config=/etc/otelcol-k8s/config.yaml
```

Send a test span. The `batch` processor holds it for up to 200 ms before the `debug` exporter prints it, so wait a
second before reading the container logs:

```bash
curl -s -X POST http://localhost:4318/v1/traces \
    -H 'Content-Type: application/json' \
    -d '{"resourceSpans":[{"scopeSpans":[{"spans":[{"traceId":"5b8efff798038103d269b633813fc60c","spanId":"eee19b7ec3c1b174","name":"test-span","kind":1,"startTimeUnixNano":"1700000000000000000","endTimeUnixNano":"1700000001000000000"}]}]}]}'
sleep 1
docker logs otelcol-k8s
```

The logs show the span, including `Name           : test-span`.

## Common use cases

### Validate a configuration

`validate` checks a configuration without starting any pipeline, so it needs no cluster:

```bash
docker run --rm \
    -v "$PWD/config.yaml:/etc/otelcol-k8s/config.yaml:ro" \
    dhi.io/opentelemetry-collector-k8s:<tag> \
    validate --config=/etc/otelcol-k8s/config.yaml
```

### Print the resolved configuration

`print-config` shows the configuration the collector would run with, after every `--config` source and `--set` override
is resolved. It redacts secrets such as header values by default:

```bash
docker run --rm \
    -v "$PWD/config.yaml:/etc/otelcol-k8s/config.yaml:ro" \
    dhi.io/opentelemetry-collector-k8s:<tag> \
    print-config --config=/etc/otelcol-k8s/config.yaml
```

Add `--mode=unredacted` to show secrets as written, and `--format=json` for JSON, which upstream considers unstable.

### List the available components

```bash
docker run --rm dhi.io/opentelemetry-collector-k8s:<tag> components
```

### Inspect feature gates

`featuregate` lists the collector's feature gates with their state and stage. Pass a gate ID to describe one:

```bash
docker run --rm dhi.io/opentelemetry-collector-k8s:<tag> featuregate
docker run --rm dhi.io/opentelemetry-collector-k8s:<tag> featuregate processor.k8sattributes.EmitV1K8sConventions
```

To change a gate, pass `--feature-gates` when you start the collector. Prefix a gate ID with `-` to disable it.

### Generate a shell completion script

`completion` prints a completion script for `bash`, `zsh`, `fish` or `powershell`. For example, to install the bash
script on a host:

```bash
docker run --rm dhi.io/opentelemetry-collector-k8s:<tag> completion bash > otelcol-k8s.bash
```

### Run with a read-only root filesystem

The collector writes nothing to its own filesystem at startup, so it runs with `--read-only` and no `tmpfs`:

```bash
docker run --rm --read-only \
    -p 4318:4318 \
    -v "$PWD/config.yaml:/etc/otelcol-k8s/config.yaml:ro" \
    dhi.io/opentelemetry-collector-k8s:<tag> \
    --config=/etc/otelcol-k8s/config.yaml
```

Mount the configuration, or pass it with `--config=env:<variable>`. Anything the collector writes at run time, such as
the `file` exporter's output or a persistent queue's storage, needs a writable mount.

## Non-hardened images vs. Docker Hardened Images

The Docker Hardened image runs as the nonroot user with UID and GID `65532`. The upstream image runs as `10001`. Files
that the collector reads or writes, for example a mounted configuration or a file storage directory, must be accessible
to `65532`. In Kubernetes, set `runAsUser`, `runAsGroup` and `fsGroup` to `65532` when you mount volumes that the
collector writes to.

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
