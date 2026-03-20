# k8s-device-plugin Guides

## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/k8s-device-plugin:<tag>`
- Mirrored image: `<your-namespace>/dhi-k8s-device-plugin:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this k8s-device-plugin image

This Docker Hardened k8s-device-plugin image includes:

- `nvidia-device-plugin` - Main device plugin daemon
- `gpu-feature-discovery` - GPU feature discovery tool
- `config-manager` - Configuration manager
- `mps-control-daemon` - MPS control daemon

## Start a k8s-device-plugin instance

The NVIDIA device plugin is designed to run as a Kubernetes DaemonSet. Replace `<tag>` with the image variant you want
to run.

### Deploy with Kubernetes manifest

To use the DHI image with the upstream Kubernetes manifest, replace the image reference:

```bash
# Download the upstream manifest
curl -LO https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.18.2/deployments/static/nvidia-device-plugin.yml

# Edit the manifest to use the DHI image
# Change: nvcr.io/nvidia/k8s-device-plugin:v0.18.2
# To:     dhi.io/k8s-device-plugin:0.18.2

# Apply the manifest
kubectl apply -f nvidia-device-plugin.yml
```

### Deploy with Helm

To use the DHI image with the upstream Helm chart:

```bash
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update
helm install nvdp nvdp/nvidia-device-plugin \
  --version=0.18.2 \
  --namespace kube-system \
  --set image.repository=dhi.io/k8s-device-plugin \
  --set image.tag=0.18.2
```

For detailed configuration options, refer to the [upstream documentation](https://github.com/NVIDIA/k8s-device-plugin).

### Debugging

For debugging, you can run the binary directly:

```bash
# Runtime variant (no shell)
docker run --rm dhi.io/k8s-device-plugin:<tag> --help

# Dev variant (includes shell)
docker run --rm dhi.io/k8s-device-plugin:<tag>-dev nvidia-device-plugin --help
```

### Environment variables

This image sets the following NVIDIA-specific environment variables:

| Variable                     | Description                                      | Default           |
| ---------------------------- | ------------------------------------------------ | ----------------- |
| `NVIDIA_DISABLE_REQUIRE`     | Disable strict NVIDIA runtime device checks      | `true`            |
| `NVIDIA_DRIVER_CAPABILITIES` | NVIDIA driver capabilities exposed to containers | `compute,utility` |
| `NVIDIA_VISIBLE_DEVICES`     | Which devices are visible to the container       | `all`             |

## Common k8s-device-plugin use cases

The device plugin supports several advanced GPU sharing and partitioning features:

- **Time-slicing**: Oversubscribe GPUs across multiple pods
- **MIG (Multi-Instance GPU)**: Partition GPUs for multi-tenant workloads
- **MPS (Multi-Process Service)**: Improve throughput for CUDA workloads
- **GPU Feature Discovery**: Automatically label nodes with GPU metadata

For configuration examples and detailed usage, refer to the
[upstream documentation](https://github.com/NVIDIA/k8s-device-plugin).

## Non-hardened images vs. Docker Hardened Images

When migrating from the upstream NVIDIA k8s-device-plugin image:

| Feature         | Upstream NVIDIA                            | Docker Hardened k8s-device-plugin              |
| --------------- | ------------------------------------------ | ---------------------------------------------- |
| Image reference | `nvcr.io/nvidia/k8s-device-plugin:v0.18.2` | `dhi.io/k8s-device-plugin:0.18.2`              |
| User            | root (0:0)                                 | nonroot (65532:65532) - runtime, root - compat |
| Shell           | Yes                                        | No (use `-dev` variant)                        |
| Package manager | Yes                                        | No package manager in runtime variants         |
| Tag format      | `v0.18.2` (with 'v' prefix)                | `0.18.2` (no 'v' prefix)                       |
| Attack surface  | Larger due to additional utilities         | Minimal, only essential components             |
| Debugging       | Traditional shell debugging                | Use Docker Debug or Image Mount                |

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

- Compat variants include `compat` in the tag name and are designed for compatibility with upstream configurations that
  require root access. These images:

  - The `-compat` variant runs as root and is designed for specific use cases that require elevated permissions:
  - Do not include a shell or package manager
  - Are intended for specific use cases requiring elevated permissions
  - **Use the compat variant (`0.18.2-compat`) when:**
    - Using `PASS_DEVICE_SPECS=true` for interoperability with Kubernetes CPUManager
    - Your deployment requires the device plugin to access device files with elevated permissions
    - You need compatibility with upstream configurations that expect root user

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
