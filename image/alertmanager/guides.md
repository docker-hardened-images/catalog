## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Alertmanager image

This Docker Hardened Alertmanager image includes:

- alertmanager (primary daemon)
- amtool (CLI client bundled with Alertmanager releases)

## Start an Alertmanager image

### Basic usage

The image includes a default configuration file, so you can start Alertmanager with minimal setup:

```bash
$ docker run -d --name alertmanager -p 9093:9093 \
  dhi.io/alertmanager:<tag>
```

This starts Alertmanager listening on the container port 9093 (web UI and API) using the default configuration.

### With persistent storage

For production use, mount a volume for persistent storage:

```bash
$ docker run -d --name alertmanager -p 9093:9093 \
  -v alertmanager_data:/data \
  dhi.io/alertmanager:<tag> \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/data
```

### With custom configuration

Mount your Alertmanager configuration (YAML). Persistent storage uses the default `/alertmanager` path:

```bash
$ docker run -d --name alertmanager -p 9093:9093 \
  -v /path/to/config.yml:/etc/alertmanager/alertmanager.yml:ro \
  dhi.io/alertmanager:<tag>
```

- Configuration file path (container): /etc/alertmanager/alertmanager.yml
- Storage (container): /alertmanager (default)

### Docker Compose (Prometheus + Alertmanager)

```yaml
version: '3.8'
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    ports:
      - 9090:9090
  alertmanager:
    image: dhi.io/alertmanager:<tag>
    ports:
      - 9093:9093
    volumes:
      - ./alertmanager/config.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/data

volumes:
  alertmanager_data: {}
```

In Prometheus config (prometheus.yml) point to Alertmanager(s):

```yaml
alerting:
  alertmanagers:
  - static_configs:
    - targets: ['alertmanager:9093']
```

## Environment variables and flags

Alertmanager is primarily configured via its YAML config file and command-line flags. The upstream Alertmanager releases
provide the binaries.

### Default command for Alertmanager image

This image follows the upstream Alertmanager defaults. The container's CMD (runtime flags) defaults to:

- --config.file=/etc/alertmanager/alertmanager.yml
- --storage.path=/alertmanager

You can override these flags by specifying a command or args when running the container (CLI, helm chart, or
orchestration system).

**Common Alertmanager runtime flags (passed as CMD/args or via entrypoint):**

- `--config.file=/etc/alertmanager/alertmanager.yml` (path to config)
- `--storage.path=/alertmanager` (default path for persisted data)
- `--storage.path=/data` (alternative path when explicitly mounting a volume to /data)
- `--web.listen-address=0.0.0.0:9093`

If your environment or orchestration system injects flags or environment variables, ensure files and mounted volumes are
readable/writable by the non-root UID used by the hardened image.

## Configuration example (config.yml)

A minimal Alertmanager config that routes all alerts to a webhook receiver:

```yaml
route:
  receiver: 'webhook'
receivers:
  - name: 'webhook'
    webhook_configs:
      - url: 'http://example-receiver.local:5001/'
```

Mount this file to /etc/alertmanager/alertmanager.yml when starting the container.

## Real-world use cases

- Single-node alerting (development)

  - Use a single Alertmanager instance with persistent storage. Use the default `/alertmanager` path, or mount a volume
    to `/data` and specify `--storage.path=/data`.

- High availability (production)

  - Run multiple Alertmanager replicas and configure clustering using the --cluster.\* flags. Do not load-balance across
    Alertmanager instances from Prometheus; instead, configure Prometheus with the list of Alertmanager endpoints.
  - Example run flags for clustering: `--cluster.listen-address=':9094' --cluster.peer='alertmanager-1:9094'` (consult
    upstream docs for full cluster configuration and ports).

- Integration with notification systems

  - Configure receivers for Slack, PagerDuty, OpsGenie, email, or custom webhooks in the Alertmanager config.

## Persisting data

Persist Alertmanager state by mounting a volume. The default storage path is `/alertmanager` (pre-created in the image).
You can use a custom path like `/data` by mounting a volume to `/data` and specifying `--storage.path=/data`. Note that
`/data` is not pre-created in the image; it will be created automatically when you mount a volume to it. Ensure the
mounted directory has permissions appropriate for a non-root container UID (65532 for nonroot user).

## amtool (CLI)

amtool is provided alongside the Alertmanager binary and can be used to query status and manipulate silences from within
containers or CI environments. Example (run from container):

```bash
$ docker run --rm --entrypoint amtool dhi.io/alertmanager:<tag> status --alertmanager.url=http://alertmanager:9093
```

## Notes and limitations

- The hardened image runs as a non-root user by default. Ensure mounted config and data paths are accessible to the
  container's UID.
- Container listens on 9093/tcp for the web UI and API.

<!-- Everything below here is boilerplate and should be included verbatim -->

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

| Item                                                                                                                   | Migration note                                                                                                   |
| :--------------------------------------------------------------------------------------------------------------------- | :--------------------------------------------------------------------------------------------------------------- |
| Base image                                                                                                             | Replace your base images in your Dockerfile with a Docker Hardened Image.                                        |
| Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` |                                                                                                                  |
| tag.                                                                                                                   |                                                                                                                  |
| necessary files and directories are accessible to the nonroot user.                                                    |                                                                                                                  |
| tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.         |                                                                                                                  |
| certificates                                                                                                           | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS             |
| certificates.                                                                                                          |                                                                                                                  |
| images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than  |                                                                                                                  |
| 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container.              |                                                                                                                  |
| point                                                                                                                  | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry |
| points for Docker Hardened Images and update your Dockerfile if necessary.                                             |                                                                                                                  |
| images, intended for runtime, don't contain a shell. Use `dev` images in build stages to run shell commands and then   |                                                                                                                  |
| copy artifacts to the runtime stage.                                                                                   |                                                                                                                  |

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
