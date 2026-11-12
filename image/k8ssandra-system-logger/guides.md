## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/k8ssandra-system-logger:<tag>`
- Mirrored image: `<your-namespace>/k8ssandra-system-logger:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this k8ssandra-system-logger image

This Docker Hardened k8ssandra-system-logger image includes:

- Vector (vectordotdev/vector) runtime binary installed at /usr/bin/vector
- A default configuration file at /etc/vector/vector.toml that tails /var/log/cassandra/system.log and writes to stdout
- Runs as a non-root user (UID/GID 999 - user "cassandra") to align with typical Cassandra deployments

## Start a k8ssandra-system-logger image

The image ships with Vector as the entrypoint and a default command to load /etc/vector/vector.toml. You can run the
image standalone for testing, or as a sidecar alongside Cassandra in Kubernetes. Replace `<tag>` with the specific DHI
tag you intend to use.

### Basic usage (standalone, for testing)

```bash
# Runs the container and mounts a host Cassandra log directory for testing.
# The default config reads /var/log/cassandra/system.log.
# Ensure system.log exists in the mounted directory and is readable by UID 999.
docker run --rm --name k8ssandra-syslog \
  -v /path/to/host/cassandra/logs:/var/log/cassandra:ro \
  dhi.io/k8ssandra-system-logger:<tag>
```

This command relies on the image's default entrypoint (/usr/bin/vector) and default config (/etc/vector/vector.toml).
The container will run in foreground and Vector will stream lines from /var/log/cassandra/system.log to stdout.

### Run with custom Vector configuration

```bash
docker run --rm --name k8ssandra-syslog \
  -v /path/to/host/cassandra/logs:/var/log/cassandra:ro \
  -v /path/to/my/vector.toml:/etc/vector/vector.toml:ro \
  dhi.io/k8ssandra-system-logger:<tag>
```

Mounting a custom /etc/vector/vector.toml lets you change what files are tailed and where logs are sent.

### Docker Compose sidecar example (Kubernetes-style service pair)

```yaml
version: '3.8'
services:
  cassandra:
    image: cassandra:4
    container_name: cassandra
    volumes:
      - cassandra-logs:/var/log/cassandra
  k8ssandra-system-logger:
    image: dhi.io/k8ssandra-system-logger:<tag>
    container_name: k8ssandra-system-logger
    volumes:
      - cassandra-logs:/var/log/cassandra:ro
volumes:
  cassandra-logs:
```

### Environment variables

This image does not expose configuration via environment variables by default. Configure Vector by editing
/etc/vector/vector.toml and mounting it into the container.

## Common k8ssandra-system-logger use cases

- Sidecar in Kubernetes to stream Cassandra system logs to cluster logging (stdout to be collected by DaemonSets or
  sidecars)
- Short-lived debug containers to read node logs from host paths and print them to console
- Centralized logging pipeline integration where Vector forwards logs to an HTTP or Kafka sink (via custom
  /etc/vector/vector.toml)

## Non-hardened images vs. Docker Hardened Images

Docker Hardened Images are intentionally minimal and secure. For k8ssandra-system-logger the most important differences
are:

- Security: This image runs as a nonroot user (UID 999). Ensure mounted host log directories are readable by that UID or
  provide an alternate method (adjust host permissions or run as a different user during testing).
- Minimal runtime: The runtime image contains only the Vector binary and its runtime dependencies; there is no package
  manager or interactive shell in runtime variants.
- Configuration: A default /etc/vector/vector.toml is provided and tailored to /var/log/cassandra/system.log. Customize
  by mounting your config file.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Dev variants include `dev` in the tag. These variants run as `root` and include a shell and package manager for
  debugging, inspection, and other interactive workflows.

- FIPS variants include `fips` in the tag. These variants use FIPS-capable cryptographic modules for environments that
  require FIPS-aligned cryptographic behavior.

- FIPS-dev variants combine the FIPS and dev characteristics: FIPS-capable crypto plus shell/package-management tools
  for debugging and development workflows.

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
