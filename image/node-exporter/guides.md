## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this node-exporter image

This Docker Hardened node-exporter image includes:

- node_exporter (Prometheus exporter binary) placed in the image PATH
- Minimal runtime libraries required to run the exporter
- Image exposes TCP port 9100 for metrics

## Start a node-exporter image

The node_exporter is configured primarily via command-line flags (not environment variables). The exporter listens on
port 9100 by default.

### Basic usage (monitoring the host — recommended)

To collect host-level metrics, node_exporter must access host namespaces and filesystem paths. The recommended pattern
is to run the container with host networking and PID namespaces and bind-mount the host root filesystem:

```bash
$ docker run -d --name node-exporter \
  --net=host --pid=host \
  -v "/:/host:ro,rslave" \
  dhi.io/node-exporter:<tag> \
  --path.rootfs=/host
```

Notes:

- --path.rootfs should match the mount path used for the host filesystem inside the container (here /host).
- Some collectors (for example timex) may require additional privileges such as --cap-add=SYS_TIME on certain hosts.

### Simple containerized usage (metrics from inside a container)

If you only need the exporter to expose metrics for the container itself (not the host), run it with a port mapping and
no host mounts:

```bash
$ docker run -d --name node-exporter -p 9100:9100 \
  dhi.io/node-exporter:<tag>
```

### Docker Compose (host monitoring example)

```yaml
version: '3.8'
services:
  node-exporter:
    image: dhi.io/node-exporter:<tag>
    container_name: node-exporter
    network_mode: host
    pid: host
    restart: unless-stopped
    volumes:
      - '/:/host:ro,rslave'
    command:
      - '--path.rootfs=/host'
```

### Entrypoint and ports

- Container listens on 9100/tcp by default.
- The DHI runtime entrypoint runs the exporter binary. To override flags, append them to the image command as shown
  above.

## Environment variables and configuration

node_exporter is configured using command-line flags (for example, --web.listen-address, --path.rootfs, and
--collector.\*). This image does not require any environment variables for basic operation. Common CLI flags:

| Flag                                       | Description                                             | Default                             |
| ------------------------------------------ | ------------------------------------------------------- | ----------------------------------- |
| --web.listen-address                       | Address to listen on for metrics                        | :9100                               |
| --path.rootfs                              | Prefix used to access host filesystem when bind-mounted | (empty)                             |
| --collector.<name> / --no-collector.<name> | Enable/disable collectors                               | collector defaults vary by platform |

Example: run with a custom listen address and disable the filesystem collector:

```bash
$ docker run -d --name node-exporter -p 9180:9180 \
  dhi.io/node-exporter:<tag> \
  --web.listen-address=":9180" \
  --no-collector.filesystem
```

## Common node-exporter use cases

- Host monitoring (recommended): run the exporter with host networking, PID namespace, and bind-mount / into the
  container and set --path.rootfs to the mount point. Scrape the exporter from Prometheus running on the network.

- Container-scoped metrics: run the exporter without host mounts and map the metrics port into the host for scraping.

- Kubernetes: deploy node-exporter as a DaemonSet to ensure one instance runs per node. The DaemonSet should mount the
  host filesystem and use hostPID and hostNetwork if you require full host metrics.

## Configuration examples

Prometheus scrape configuration (basic):

```yaml
scrape_configs:
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['<node-hostname-or-ip>:9100']
```

Kubernetes DaemonSet (snippet):

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
spec:
  selector:
    matchLabels:
      name: node-exporter
  template:
    metadata:
      labels:
        name: node-exporter
    spec:
      hostNetwork: true
      hostPID: true
      containers:
      - name: node-exporter
        image: dhi.io/node-exporter:<tag>
        args:
          - "--path.rootfs=/host"
        volumeMounts:
          - name: host-root
            mountPath: /host
            readOnly: true
      volumes:
        - name: host-root
          hostPath:
            path: /
```

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

### Generating SBOM and running tests locally without pushing

If you need SBOM/VEX artifacts or want to run tests locally without pushing a runtime image to a registry, follow these
steps:

1. Build the image locally. This will produce a local image tagged as dhi/<image-name>:build (for example
   dhi/node-exporter:build):

   dhi def build image/node-exporter/debian-13/1.yaml

1. Generate SBOM files for the built image (the build definition also emits SBOM outputs during the build which dhi def
   sbom will collect):

   dhi def sbom image/node-exporter/debian-13/1.yaml

   After running these commands, inspect the .build/ directory and the generated SBOM/VEX artifacts to confirm
   dependencies and mitigations.

1. Run the test suite using the locally built image to avoid test harnesses trying to pull a published image (useful for
   local development or CI that builds the image as a prior step):

   DHI_TEST_IMAGE=dhi/node-exporter:build go test ./image/node-exporter/tests -v

Note: The DHI test harness already supports the DHI_TEST_IMAGE environment variable; the tests also attempt to
auto-detect a local build via .build/latest.yaml or by building the image from the tests/ working directory. Overriding
DHI_TEST_IMAGE is the simplest approach to guarantee the tests use a local image and avoid pull errors when a remote
registry is not available or requires authentication.
