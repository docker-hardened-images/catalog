## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Telegraf is a plugin-driven server agent for collecting, processing, aggregating, and writing metrics. It supports a
wide variety of input plugins for collecting metrics from systems, services, and third-party APIs.

### Running Telegraf

Telegraf requires a configuration file. You can mount your own configuration file into the container:

```bash
docker run --rm -v $PWD/telegraf.conf:/etc/telegraf/telegraf.conf:ro \
  dhi.io/telegraf:<tag>
```

### Generating a default configuration

To generate a default configuration file:

```bash
docker run --rm dhi.io/telegraf:<tag> config > telegraf.conf
```

The generated file is a starting point. Add at least one output plugin before using it to start Telegraf.

### Using additional configuration files

You can mount a directory of configuration files to `/etc/telegraf/telegraf.d/`:

```bash
docker run --rm \
  -v $PWD/telegraf.conf:/etc/telegraf/telegraf.conf:ro \
  -v $PWD/telegraf.d:/etc/telegraf/telegraf.d:ro \
  dhi.io/telegraf:<tag>
```

### Checking the version

```bash
docker run --rm dhi.io/telegraf:<tag> version
```

## Deploy Telegraf using Helm

The recommended way to deploy Telegraf in production Kubernetes environments is using the
[InfluxData Helm chart](https://github.com/influxdata/helm-charts/tree/master/charts/telegraf).

### Step 1: Add the Helm repository

```bash
helm repo add influxdata https://helm.influxdata.com/
helm repo update
```

### Step 2: Install with a Docker Hardened Image

```bash
helm install telegraf influxdata/telegraf \
  --set image.repo=dhi.io/telegraf \
  --set image.tag=<tag>
```

### Step 3: Verify the deployment

```bash
kubectl get pods -l app.kubernetes.io/name=telegraf
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
| Non-root user      | The DHI image runs as a nonroot user with UID/GID `65532` instead of `999`/`999` in the upstream image. If you are mounting volumes with data owned by the upstream UID (999), you must update ownership or run with `--user 999:999`.                                                                                       |
| Entry point        | The DHI image runs the `telegraf` binary directly (`["telegraf"]`) instead of the upstream `/entrypoint.sh` wrapper script. See [Entrypoint differences](#entrypoint-differences) below.                                                                                                                                     |
| No default config  | The DHI image does not ship a default `telegraf.conf`. You must mount your own configuration file. Use `docker run --rm dhi.io/telegraf:<tag> config` to generate a default configuration.                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

### Entrypoint differences

The upstream Telegraf image uses an `/entrypoint.sh` wrapper script that performs the following before starting
Telegraf:

- Grants `cap_net_raw` and `cap_net_bind_service` capabilities to the Telegraf binary, allowing ICMP ping inputs and
  binding to privileged ports when running as root.
- Drops privileges from root to the `telegraf` user using `setpriv`.
- Honors additional groups supplied via `docker run --group-add`.

The DHI image runs the `telegraf` binary directly without this wrapper. This means:

- **ICMP ping inputs**: If you use the `ping` input plugin, you may need to grant `NET_RAW` capability explicitly using
  `--cap-add NET_RAW` when running the container.
- **Privileged ports**: The DHI image runs as a non-root user by default. To bind to ports below 1024, configure your
  application to use higher ports or add `NET_BIND_SERVICE` capability.
- **Group membership**: Additional groups via `--group-add` are applied directly by the container runtime without the
  entrypoint wrapper.

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
