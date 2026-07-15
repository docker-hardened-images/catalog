## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/beyla:<tag>`
- Mirrored image: `<your-namespace>/dhi-beyla:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a beyla image

Beyla instruments *other* processes by attaching eBPF probes in the kernel. It therefore must run with elevated
privileges and share the target's PID namespace:

- **Privileges:** `CAP_BPF` plus `CAP_SYS_ADMIN` (or, on kernels 5.8+, the finer set `CAP_PERFMON`, `CAP_NET_RAW`,
  `CAP_DAC_READ_SEARCH`, `CAP_SYS_PTRACE`, and `CAP_CHECKPOINT_RESTORE`; add `CAP_NET_ADMIN` for network/TC features).
  For local experiments, `--privileged` is the simplest option.
- **Kernel:** Linux 4.18+ with BTF enabled (5.8+ recommended). Mount the host BTF with `-v /sys:/sys:ro` when it is not
  already visible.
- **Target visibility:** run with `--pid=host` (or in the same Kubernetes pod) so Beyla can see the process to
  instrument.

The image runs as root and uses the entrypoint `/usr/local/bin/beyla`. Beyla is configured entirely through environment
variables and/or a YAML config file (`BEYLA_CONFIG_PATH`); it has no subcommands.

```bash
$ docker run --rm --privileged --pid=host \
  -e BEYLA_OPEN_PORT=8080 \
  -e BEYLA_TRACE_PRINTER=text \
  dhi.io/beyla:<tag>
```

This selects the process listening on port 8080 as the instrumentation target and prints captured request traces to
standard output.

## Common beyla use cases

### Print traces for a local service to stdout

The quickest way to confirm Beyla is instrumenting a workload. Beyla selects the target by listening port and prints a
span line per captured request, which is useful for validating connectivity before wiring up a backend.

```bash
$ docker run --rm --privileged --pid=host \
  -e BEYLA_OPEN_PORT=8080 \
  -e BEYLA_TRACE_PRINTER=text \
  -e BEYLA_SERVICE_NAME=my-service \
  dhi.io/beyla:<tag>
```

### Export OpenTelemetry traces and metrics to a collector

In production Beyla pushes OTLP to a collector or Grafana Alloy. The following Compose file runs Beyla alongside an
OpenTelemetry Collector and instruments every process on the host.

```yaml
services:
  beyla:
    image: dhi.io/beyla:<tag>
    pid: "host"
    privileged: true
    environment:
      BEYLA_OPEN_PORT: "8080"
      BEYLA_SERVICE_NAMESPACE: demo
      OTEL_EXPORTER_OTLP_ENDPOINT: http://otelcol:4317
    depends_on:
      - otelcol
  otelcol:
    image: otel/opentelemetry-collector:latest
    ports:
      - "4317:4317"
```

### Configure Beyla with a YAML config file

For anything beyond a couple of settings, mount a config file and point `BEYLA_CONFIG_PATH` at it.

```bash
$ docker run --rm --privileged --pid=host \
  -v "$(pwd)/beyla-config.yml:/etc/beyla/config.yml:ro" \
  -e BEYLA_CONFIG_PATH=/etc/beyla/config.yml \
  dhi.io/beyla:<tag>
```

`beyla-config.yml`:

```yaml
discovery:
  instrument:
    - open_ports: 8080
trace_printer: text
otel_traces_export:
  endpoint: http://otelcol:4317
```

### Expose Beyla metrics for Prometheus

Beyla can expose an internal Prometheus scrape endpoint instead of (or in addition to) pushing OTLP.

```bash
$ docker run --rm --privileged --pid=host -p 9090:9090 \
  -e BEYLA_OPEN_PORT=8080 \
  -e BEYLA_PROMETHEUS_PORT=9090 \
  dhi.io/beyla:<tag>
```

For advanced setups — Kubernetes DaemonSet deployment, distributed-trace context propagation, network metrics, and
language-specific instrumentation — see the [Grafana Beyla documentation](https://grafana.com/docs/beyla/).

## Non-hardened images vs. Docker Hardened Images

Like the upstream `grafana/beyla` image, this image runs as root and requires eBPF privileges (`CAP_BPF` /
`CAP_SYS_ADMIN`) and a BTF-enabled kernel — these requirements are inherent to eBPF instrumentation, not added by
hardening. The entrypoint is `/usr/local/bin/beyla`; the upstream binary path `/beyla` remains available as a symlink,
so existing commands and Helm charts that exec `/beyla` keep working.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  > **Note:** Unlike most DHI runtime images, this image runs as **root** because eBPF instrumentation requires elevated
  > kernel privileges.

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

| Item               | Migration note                                                                                                                                                                                                             |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                  |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                |
| Non-root user      | Most non-dev DHI images run as the nonroot user, but this image runs as **root** because eBPF instrumentation requires elevated privileges (`CAP_BPF` / `CAP_SYS_ADMIN`). This matches the upstream `grafana/beyla` image. |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                 |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                         |
| Ports              | Most non-dev DHI images run as nonroot and can't bind privileged ports (below 1024). This image runs as root, so that restriction does not apply.                                                                          |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                |

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

Most DHI runtime images run as the nonroot user, but this image runs as root because eBPF instrumentation requires
elevated kernel privileges. Ensure the container runtime grants the capabilities described under
[Start a beyla image](#start-a-beyla-image).

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
