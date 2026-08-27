## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/dapr-scheduler:1`
- Mirrored image: `<your-namespace>/dhi-dapr-scheduler:1`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Dapr Scheduler is a Dapr control-plane service. It is usually deployed as part of a Dapr installation rather than run as
an isolated application container. For deployment architecture, configuration, and day-two operations, use the upstream
Dapr documentation:

- https://docs.dapr.io/operations/components/setup-supported-schedulers/
- https://docs.dapr.io/operations/hosting/kubernetes/kubernetes-overview/

This guide stays focused on a quick-start flow for the hardened image and the small number of migration details that are
specific to DHI packaging.

## Image contents

This image includes:

- the `dapr-scheduler` binary at `/usr/local/bin/dapr-scheduler`
- an upstream-compatible `/scheduler` path for manifests or command overrides that expect the upstream binary location

## Configuration reference

The scheduler flag set changes over time, so this guide does not duplicate a static flag table. Use the upstream Dapr
documentation linked above for configuration guidance, and inspect the scheduler help output in your environment when
you need the exact CLI surface for the image version you are running.

## Run a standalone scheduler

When you run the scheduler directly as a nonroot container, provide a writable `--etcd-data-dir`. The upstream default
is a relative `./data` path, which is not appropriate for a minimal runtime image launched from `/`.

```bash
docker run --rm \
  -p 8080:8080 \
  -p 50006:50006 \
  dhi.io/dapr-scheduler:1 \
  --etcd-data-dir /tmp/dapr-scheduler
```

After startup, the health endpoint is available at:

```console
$ curl http://localhost:8080/healthz
```

If you need scheduler state to survive container restarts, mount a writable directory or volume and point
`--etcd-data-dir` at that location instead of `/tmp`.

## Upstream compatibility note

The upstream `daprio/scheduler` image does not define an entrypoint, so direct `docker run` usage normally looks like
`/scheduler --help` or `/scheduler --etcd-data-dir ...`.

The hardened image sets the entrypoint to `dapr-scheduler`, so you can pass scheduler flags directly without adding an
explicit binary path or overriding the entrypoint.

The upstream `/scheduler` path is still preserved for compatibility with manifests that explicitly override the command.
For example, a manifest can continue to point at the upstream binary path:

```yaml
containers:
  - name: scheduler
    image: dhi.io/dapr-scheduler:1
    command: ["/scheduler"]
    args:
      - --etcd-data-dir
      - /tmp/dapr-scheduler
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
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
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                 |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                    |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                        |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                               |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                               |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   If you're using a multi-stage build, update the runtime stage to use a non-dev hardened image. This ensures your
   production containers run with minimal attack surface.

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
