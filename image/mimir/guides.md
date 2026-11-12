## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Mimir instance

The Docker Hardened Mimir image requires a configuration file to start. Mimir has no built-in default configuration, so
you must supply one via `--config.file`. The HTTP API and query frontend are served on port 8080; the gRPC listener is
on port 9095.

Create a minimal configuration file for monolithic mode using local filesystem storage:

```yaml
multitenancy_enabled: false

blocks_storage:
  backend: filesystem
  filesystem:
    dir: /var/mimir/blocks
  bucket_store:
    sync_dir: /var/mimir/tsdb-sync

alertmanager:
  data_dir: /var/mimir/alertmanager-data

compactor:
  data_dir: /var/mimir/compactor-data

ruler:
  rule_path: /var/mimir/ruler-data

alertmanager_storage:
  backend: filesystem
  filesystem:
    dir: /var/mimir/alertmanager

ruler_storage:
  backend: filesystem
  filesystem:
    dir: /var/mimir/ruler

ingester:
  ring:
    replication_factor: 1
```

Run Mimir in monolithic mode with the configuration above, replacing `<tag>` with the image variant you want to run:

```bash
$ docker run -d --name mimir \
  -v /path/to/mimir.yaml:/etc/mimir/config.yaml:ro \
  -v mimir_data:/var/mimir \
  -p 8080:8080 \
  dhi.io/mimir:<tag> \
  --config.file=/etc/mimir/config.yaml \
  --target=all
```

Verify Mimir is ready:

```bash
$ curl http://localhost:8080/ready
ready
```

## Common Mimir use cases

## Mount a configuration file

Mount your Mimir configuration file into the container at a path you reference with `--config.file`. Mimir supports YAML
configuration files and also accepts configuration via environment variable overrides using the `MIMIR_<SECTION>_<KEY>`
pattern.

```bash
$ docker run -d --name mimir \
  -v /path/to/mimir.yaml:/etc/mimir/config.yaml:ro \
  -p 8080:8080 \
  dhi.io/mimir:<tag> \
  --config.file=/etc/mimir/config.yaml \
  --target=all
```

## Persist metric storage

Mimir stores block data, compactor state, and other persistent data on disk. The image pre-creates `/var/mimir` with
ownership `65532:65532`, which matches the nonroot user the container runs as. Mount a named volume to `/var/mimir` and
no additional permission setup is required:

```bash
$ docker run -d --name mimir \
  -v /path/to/mimir.yaml:/etc/mimir/config.yaml:ro \
  -v mimir_data:/var/mimir \
  -p 8080:8080 \
  dhi.io/mimir:<tag> \
  --config.file=/etc/mimir/config.yaml \
  --target=all
```

If you mount a volume to a custom path, Docker auto-creates the target as `root:root`, which the nonroot user (UID
65532\) cannot write to. Pre-chown the volume before starting Mimir:

```bash
$ docker volume create mimir_data
$ docker run --rm -v mimir_data:/data --user 0 \
    dhi.io/busybox:<tag> chown -R 65532:65532 /data
$ docker run -d --name mimir \
  -v /path/to/mimir.yaml:/etc/mimir/config.yaml:ro \
  -v mimir_data:/data \
  -p 8080:8080 \
  dhi.io/mimir:<tag> \
  --config.file=/etc/mimir/config.yaml \
  --target=all
```

For host bind-mounts, run `chown -R 65532:65532` on the host directory before starting the container.

## Run with Prometheus using Docker Compose

Run Prometheus and Mimir together using Docker Compose. Prometheus remote-writes metrics to Mimir, and Mimir exposes a
Prometheus-compatible query API so Grafana can query both.

```yaml
services:
  mimir:
    image: dhi.io/mimir:<tag>
    command:
      - --config.file=/etc/mimir/config.yaml
      - --target=all
    volumes:
      - ./mimir.yaml:/etc/mimir/config.yaml:ro
      - mimir_data:/var/mimir
    ports:
      - 8080:8080

  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
    ports:
      - 9090:9090

volumes:
  mimir_data: {}
```

In `prometheus.yml`, add a remote write section pointing to Mimir's push endpoint:

```yaml
remote_write:
  - url: http://mimir:8080/api/v1/push
    headers:
      X-Scope-OrgID: anonymous
```

Mimir's query API is Prometheus-compatible; configure it as a Prometheus data source in Grafana at
`http://mimir:8080/prometheus`.

## Non-hardened images vs Docker Hardened Images

## Key differences

| Feature         | Docker Official Mimir               | Docker Hardened Mimir                                   |
| --------------- | ----------------------------------- | ------------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches            |
| Shell access    | Full shell (`sh`) available         | No shell in runtime variants                            |
| Package manager | Package manager available           | No package manager in runtime variants                  |
| User            | Runs as root by default             | Runs as nonroot user (UID 65532)                        |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                      |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting     |
| Storage path    | No pre-created data dir             | `/var/mimir` pre-created with `65532:65532`             |
| Compliance      | None                                | CIS; FIPS 140-3 and STIG in FIPS variants               |
| Attestations    | None                                | SBOM, provenance, VEX metadata, FIPS (on FIPS variants) |

## Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- Docker Debug to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```bash
$ docker debug mimir
```

Or mount debugging tools with the Image Mount feature:

```bash
$ docker run --rm -it --pid container:mimir \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  --entrypoint /dbg/bin/sh \
  dhi.io/mimir:<tag>
```

For Mimir specifically, most operational inspection can also be done through the HTTP API without a shell: `/ready`,
`/metrics`, `/config`, `/runtime-config`, `/memberlist`, and the full Prometheus-compatible query API.

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
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                     |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                          |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                        |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user (UID 65532). Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                             |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                 |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Mimir's default ports 8080 and 9095 work without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary. The Mimir image entry point is the `mimir` binary.                                     |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use `dev` images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                      |
| Storage path       | Mount persistent volumes to `/var/mimir` (pre-created with ownership `65532:65532`). For custom paths, pre-chown the mount target to `65532:65532`.                                                                                                                                |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. **Install additional packages.**

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
