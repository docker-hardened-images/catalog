## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/pushgateway:<tag>`
- Mirrored image: `<your-namespace>/dhi-pushgateway:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this pushgateway image

This Docker Hardened pushgateway image includes:

- The `pushgateway` binary (statically built)
- Minimal runtime filesystem prepared for secure execution as a nonroot user

## Start a pushgateway image

The Pushgateway listens on port 9091 by default. Use the following examples to run the hardened image.

### Basic usage

```console
$ docker run -d --name pushgateway -p 9091:9091 \
  dhi.io/pushgateway:<tag>
```

Verify the container is running and healthy:

```console
$ docker ps --filter name=pushgateway
$ curl -s http://localhost:9091/-/healthy
```

To pass command-line flags to the Pushgateway (for example to change the listen address or enable persistence), append
them after the image name:

```console
$ docker run -d --name pushgateway -p 9091:9091 \
  dhi.io/pushgateway:<tag> --web.listen-address=":9091" --persistence.file=/data/pushgateway.snap
```

Verify the container is running and check the logs:

```console
$ docker ps --filter name=pushgateway
$ curl -s http://localhost:9091/-/healthy
$ docker logs pushgateway
```

### Docker Compose example

Create a directory for your project and the required configuration files:

```console
$ mkdir -p pushgateway-test && cd pushgateway-test
```

Create `prometheus.yml`:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'pushgateway'
    honor_labels: true
    static_configs:
      - targets: ['pushgateway:9091']
```

Create `docker-compose.yaml`:

```yaml
services:
  pushgateway:
    image: dhi.io/pushgateway:<tag>
    container_name: pushgateway
    ports:
      - "9091:9091"
    volumes:
      - ./pushgateway-data:/data
    command:
      - "--web.listen-address=:9091"
      - "--persistence.file=/data/pushgateway.snap"

  prometheus:
    image: dhi.io/prometheus:<tag>
    container_name: prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    ports:
      - "9090:9090"
```

### Environment / configuration

Pushgateway is configured primarily via command-line flags (not environment variables). The hardened image does not
introduce custom environment variables for configuration. Common flags include:

| Flag                 | Description                                                                | Example                  |
| -------------------- | -------------------------------------------------------------------------- | ------------------------ |
| --web.listen-address | Address and port to listen on                                              | ":9091"                  |
| --persistence.file   | Path to a file where metrics are persisted across restarts                 | "/data/pushgateway.snap" |
| --web.route-prefix   | Prefix at which the web UI and metrics are served (if used behind a proxy) | "/"                      |

You can pass flags directly as arguments to the container (see examples above).

## Common pushgateway use cases

- Basic local testing: run a single container and push metrics from short-lived jobs.

  Push a metric with curl:

  ```console
  $ echo "some_metric 3.14" | curl --data-binary @- http://localhost:9091/metrics/job/some_job
  ```

  Verify the metric was pushed:

  ```console
  $ curl -s http://localhost:9091/metrics | grep some_metric
  ```

- Persisted Pushgateway: mount a host volume for persistence and pass `--persistence.file` so metrics survive restarts:

  ```console
  $ docker run -d --name pushgateway -p 9091:9091 \
    -v /var/lib/pushgateway:/data \
    dhi.io/pushgateway:<tag> --persistence.file=/data/pushgateway.snap
  ```

  Push a test metric and verify:

  ```console
  $ echo "persist_test 3.14" | curl --data-binary @- http://localhost:9091/metrics/job/persist_job
  $ curl -s http://localhost:9091/metrics | grep persist_test
  ```

- Prometheus + Pushgateway in Compose: use the Compose example above and configure Prometheus to scrape the Pushgateway.
  Be sure to set `honor_labels: true` in Prometheus' scrape config to avoid overwritten job/instance labels.

## Example: Pushing metrics from a shell script

A simple shell script that pushes a metric (note the newline at end of each metric line):

```bash
#!/bin/sh
echo "batch_job_success 1" | curl --data-binary @- http://pushgateway:9091/metrics/job/batch_job
```

## Non-hardened images vs. Docker Hardened Images

The Docker Hardened pushgateway image differs from the standard Prometheus pushgateway image in the following ways:

| Feature         | Standard pushgateway        | Docker Hardened pushgateway            |
| --------------- | --------------------------- | -------------------------------------- |
| User            | Runs as nobody              | Runs as nonroot (UID 65532)            |
| Shell access    | Shell available             | No shell in runtime variants           |
| Package manager | May include package manager | No package manager in runtime variants |
| Attack surface  | Standard base image         | Minimal, only essential components     |
| Debugging       | Traditional shell debugging | Use Docker Debug for troubleshooting   |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```console
$ docker debug <container-name>
```

Inside the debug session, you can run commands like `ps aux`, `netstat -tlnp`, or `curl` to inspect the container.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

The Pushgateway image provides runtime, dev, and FIPS variants. Runtime variants are designed to run your application in
production. These images are intended to be used either directly or as the `FROM` image in the final stage of a
multi-stage build. These images typically:

- Run as a nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Dev variants include `dev` in the tag name and are intended for debugging or as a base for custom images. These images
include a shell and package manager, and run as root.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

### FIPS variants

FIPS variants include `fips` in the variant name and tag. These variants use cryptographic modules that have been
validated under FIPS 140, a U.S. government standard for secure cryptographic operations. Docker Hardened Pushgateway
images include FIPS-compliant variants for environments requiring Federal Information Processing Standards compliance.

#### Steps to verify FIPS:

```console
# Compare image sizes (FIPS variants are larger due to FIPS crypto libraries)
$ docker images | grep pushgateway

# Verify FIPS compliance using image labels
$ docker inspect dhi.io/pushgateway:<tag>-fips \
  --format '{{index .Config.Labels "com.docker.dhi.compliance"}}'
fips,stig,cis
```

#### Runtime requirements specific to FIPS:

- FIPS mode enforces stricter cryptographic standards
- Use FIPS variants when exposing metrics over HTTPS with FIPS-compliant TLS
- Required for deployments in US government or regulated environments
- Only FIPS-approved cryptographic algorithms are available for TLS connections

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                                                    |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                                       |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
