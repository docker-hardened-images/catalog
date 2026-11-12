## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/dcgm-exporter:<tag>`
- Mirrored image: `<your-namespace>/dhi-dcgm-exporter:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this dcgm-exporter image

DCGM Exporter is a Prometheus exporter for NVIDIA GPU metrics, built on top of the NVIDIA Data Center GPU Manager (DCGM)
C library. It exposes GPU telemetry (including SM clock frequency, memory usage, temperature, power draw, and hardware
profiling counters) as a Prometheus-compatible `/metrics` endpoint on port 9400. The exporter uses CGo to call into
`libdcgm.so` at runtime, and the set of exported metrics is controlled by a counter CSV file
(`/etc/dcgm-exporter/default-counters.csv` by default, overridable via `DCGM_EXPORTER_COLLECTORS`).

The `dcgm-exporter` binary is built from source and is Apache-2.0. The bundled DCGM libraries (`libdcgm.so.4` and its
modules, including `libdcgmmoduleprofiling.so`) are NVIDIA prebuilt binaries distributed under the NVIDIA Data Center
GPU Manager license, redistributed here with NVIDIA's permission. The `libnvperf_dcgm_host.so` library, which NVIDIA
requires for profiling counters (`DCGM_FI_PROF_*` fields) on Ampere (A100) and older GPU architectures (Volta, Turing),
is intentionally excluded. Profiling counters on Hopper (H100) and newer GPUs use open hardware performance counters and
work without that library. On Ampere and older GPUs, `DCGM_FI_PROF_*` fields return zero. Basic device metrics
(`DCGM_FI_DEV_*`) work on all supported GPU generations.

### Run the dcgm-exporter container

The exporter requires the NVIDIA container runtime on the host. Pass `--gpus all` to expose GPU devices to the
container.

```bash
docker run -d --gpus all --rm \
  -p 9400:9400 \
  dhi.io/dcgm-exporter:<tag>
```

Once running, metrics are available at `http://localhost:9400/metrics`.

To display help information for the binary:

```bash
docker run --rm --gpus all dhi.io/dcgm-exporter:<tag> --help
```

### Container user

This image runs as root (uid 0). Most DHI images default to a nonroot user, but dcgm-exporter forks `/sbin/ldconfig` at
startup to refresh the dynamic linker cache for `libdcgm.so`, and that path requires uid 0. This matches upstream
NVIDIA's image behavior.

### Enable profiling metrics with SYS_ADMIN

Basic `DCGM_FI_DEV_*` metrics work without elevated privileges. Profiling metrics (`DCGM_FI_PROF_*`) require the
`SYS_ADMIN` capability, because DCGM uses perf event interfaces to read hardware performance counters. Pass
`--cap-add SYS_ADMIN` at runtime to enable them; the capability is not granted by default.

To enable profiling metrics in Docker:

```bash
docker run -d --gpus all --rm \
  --cap-add SYS_ADMIN \
  -p 9400:9400 \
  dhi.io/dcgm-exporter:<tag>
```

To enable profiling metrics in Kubernetes, add the capability to the container's security context:

```yaml
securityContext:
  capabilities:
    add:
      - SYS_ADMIN
```

> **Note:** On Ampere and older GPU architectures, profiling fields may still return zero even with `SYS_ADMIN` because
> this image does not ship `libnvperf_dcgm_host.so` (proprietary). Profiling works without it on Hopper and newer
> hardware.

### Docker Compose with Prometheus

The following Compose example starts dcgm-exporter alongside Prometheus on a GPU node.

```yaml
services:
  dcgm-exporter:
    image: dhi.io/dcgm-exporter:<tag>
    runtime: nvidia
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
    ports:
      - "9400:9400"
    cap_add:
      - SYS_ADMIN  # required for DCGM_FI_PROF_* profiling metrics

  prometheus:
    image: dhi.io/prometheus:<tag>
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
```

Add a scrape job to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: dcgm
    scrape_interval: 15s
    static_configs:
      - targets: ["dcgm-exporter:9400"]
```

### Deploy on Kubernetes with Helm

The upstream Helm chart is the recommended way to run dcgm-exporter in Kubernetes. To use the Docker Hardened image,
override the image reference at install time:

```bash
helm repo add gpu-helm-charts https://nvidia.github.io/dcgm-exporter/helm-charts
helm repo update

helm install dcgm-exporter gpu-helm-charts/dcgm-exporter \
  --set image.repository=dhi.io/dcgm-exporter \
  --set image.tag=<VERSION>
```

For detailed configuration options, see the [upstream Helm chart documentation](https://github.com/NVIDIA/dcgm-exporter)
and the [NVIDIA GPU telemetry guide](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/dcgm-exporter.html).

### Non-hardened images vs. Docker Hardened Images

| Feature                  | Upstream NVIDIA                          | Docker Hardened dcgm-exporter                          |
| ------------------------ | ---------------------------------------- | ------------------------------------------------------ |
| Image reference          | `nvcr.io/nvidia/k8s/dcgm-exporter:<tag>` | `dhi.io/dcgm-exporter:<tag>`                           |
| User                     | root                                     | root (required for ldconfig fork; matches upstream)    |
| Shell                    | Yes                                      | No (use `-dev` variant or Docker Debug)                |
| Package manager          | Yes                                      | No (runtime variant)                                   |
| `libnvperf_dcgm_host.so` | Included (proprietary)                   | Not included; profiling on Ampere and older may differ |
| SYS_ADMIN default        | Required (passed explicitly)             | Optional; only needed for `DCGM_FI_PROF_*` metrics     |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  > **Note:** Unlike most DHI runtime images, this image runs as **root** (uid 0). See [Container user](#container-user)
  > for the reason.

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
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
| Non-root user      | Most non-dev DHI images run as the nonroot user, but this image runs as **root** (uid 0) because dcgm-exporter forks `/sbin/ldconfig` at startup, which requires uid 0. See [Container user](#container-user).                                                                                                               |
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

Most DHI runtime images run as the nonroot user, but this image runs as root (uid 0); see
[Container user](#container-user). Ensure that necessary files and directories are accessible to the user the container
runs as. You may need to copy files to different directories or change permissions so your application can access them.

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
