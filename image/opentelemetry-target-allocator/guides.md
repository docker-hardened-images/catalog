## Prerequisites

- Mirror the image to your organization's registry (see Docker registry tooling).
- Replace `<your-namespace>` with your organization namespace and `<tag>` with the image tag in examples below.

## What's included in this opentelemetry-target-allocator image

This Docker Hardened opentelemetry-target-allocator image includes:

- target-allocator binary (built from cmd/otel-allocator)
- minimal runtime libraries required to run the HTTP server

## Start the Target Allocator image

The Target Allocator listens on :8080 by default and exposes HTTP endpoints used by OpenTelemetry Collector instances:

- /jobs — list of configured jobs
- /jobs/{job}/targets — targets assigned for a given job
- /scrape_configs — raw scrape_configs (JSON)
- /metrics — Prometheus metrics
- /livez and /readyz — liveness/readiness probes

Note: The upstream operator typically exposes the Target Allocator as a Service on port 80 (cluster service) while the
container listens on 8080.

## Configuration

The Target Allocator requires a configuration file at /conf/targetallocator.yaml. When running the container directly
(outside the operator), you must provide this file via a volume mount:

```bash
docker run -v /path/to/your/targetallocator.yaml:/conf/targetallocator.yaml <your-namespace>/dhi-opentelemetry-target-allocator:<tag>
```

The operator provides configuration examples in the upstream repo and documentation:
https://opentelemetry.io/docs/platforms/kubernetes/operator/target-allocator/

Common configuration choices:

- allocation_strategy: consistent-hashing (default) or other supported strategies
- filter_strategy: relabel-config (default)
- prometheus_cr.enabled: enable discovery from Prometheus CRs
- --enable-https-server / TLS configuration: enable mTLS/HTTPS for secret-valued scrape_configs

You can also pass command-line flags (the binary uses standard CLI flags) to override defaults; when running under the
operator these are set via the Helm chart values.

## Environment / Files

| File / Flag                | Purpose                                                    |
| -------------------------- | ---------------------------------------------------------- |
| /conf/targetallocator.yaml | Primary configuration file (must be mounted via volume)    |
| --kubeconfig-path          | Path to kubeconfig to use when running outside the cluster |
| --enable-https-server      | Enable HTTPS server (mTLS) to serve secret-valued configs  |

## Common use cases

- Basic deployment in Kubernetes via upstream Helm chart (recommended)
- Use as a service behind the OpenTelemetry Operator to shard scrape targets among Collectors
- Enable Prometheus CR discovery to automatically ingest ServiceMonitor/PodMonitor resources

## Non-hardened images vs. Docker Hardened Images

This Docker Hardened image is a minimal, security-focused build of the upstream Target Allocator. It contains only the
runtime binary and required libraries and by default runs as a nonroot user in non-dev variants. For building the binary
or running administrative/debug tasks, use the `-dev` variant which includes package managers and shells.

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
