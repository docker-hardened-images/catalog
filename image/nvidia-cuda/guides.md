## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/nvidia-cuda:<tag>`
- Mirrored image: `<your-namespace>/dhi-nvidia-cuda:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this CUDA image

This image installs the NVIDIA CUDA runtime libraries (`cuda-runtime-13-2`) from NVIDIA's official Debian 13 apt
repository. The dev variant adds `cuda-minimal-build-13-2`, which includes the `nvcc` compiler, cudart and the CUDA
libraries plus their headers, and build utilities (`cuobjdump`, `ptxas`, `nvlink`, `fatbinary`, `cu++filt`).

Standard NVIDIA Container Toolkit environment variables are set:

- `NVIDIA_VISIBLE_DEVICES=all`
- `NVIDIA_DRIVER_CAPABILITIES=compute,utility`
- `NVIDIA_REQUIRE_CUDA=cuda>=<major.minor>` (nvidia-container-toolkit rejects hosts with too-old drivers up front rather
  than failing at first CUDA call)
- `NVARCH=x86_64` or `sbsa` per build platform
- `CUDA_VERSION=<version>`
- `LD_LIBRARY_PATH` includes `/usr/local/cuda/lib64`
- `PATH` includes `/usr/local/cuda/bin`

The runtime variant does not ship the CUDA toolkit binaries under `/usr/local/cuda/bin` (no nvcc, compute-sanitizer,
cuobjdump, etc.); only the runtime libraries under `/usr/local/cuda/lib64`. Switch to the `-dev` variant if you need
those tools.

### Run the container

The image requires the NVIDIA container runtime on the host. Pass `--gpus all` to expose GPU devices to the container.

```bash
docker run --rm --gpus all dhi.io/nvidia-cuda:13.2 nvidia-smi
```

Build and run a CUDA application with the dev variant:

```bash
docker run --rm --gpus all -v "$PWD":/workspace dhi.io/nvidia-cuda:13.2-dev \
  bash -lc "nvcc -o vector_add vector_add.cu && ./vector_add"
```

The runtime and cuDNN variants ship no default command, because CUDA is a library base with no standalone executable
(the same posture as the `static` base image). Invoke them with an explicit command as shown above, or use them as the
`FROM` image in a build. For an interactive shell, use the `-dev` variant, for example
`docker run --rm -it dhi.io/nvidia-cuda:13.2-dev`.

### Container user

This image runs as root in the dev variant (matching upstream NVIDIA convention) and as the default DHI nonroot user
(uid 65532) in the runtime variant. CUDA applications typically need device file access provided by the NVIDIA Container
Toolkit; the runtime image does not require additional privileges beyond what the toolkit grants.

If you `COPY --from=builder` into the runtime variant, pass `--chown=65532:65532` so the nonroot user can read or
execute the copied files. The default work directory `/workspace` is already owned by uid 65532.

### Profiling tools

The dev variant installs `cuda-minimal-build-13-2` rather than the full `cuda-toolkit-13-2`. The toolkit metapackage
hard-depends on `cuda-nsight`, `cuda-nsight-compute`, and `cuda-nsight-systems`; those bundle GUI profiling tooling that
needs an X display to use, and they ship with Go binaries pinned to older Go stdlib releases. If you need nsight
profiling for a specific workload, use upstream `nvidia/cuda:<tag>-devel-*` (Docker Hub, also mirrored on
`nvcr.io/nvidia/cuda`) or install the standalone `nsight-compute` and `nsight-systems` tools on the host.

### CUDA version availability

This image is published from NVIDIA's `developer.download.nvidia.com/compute/cuda/repos/debian13/` apt repo. As of
publication, NVIDIA publishes CUDA 13.1.x and 13.2.x for Debian 13 on x86_64 and sbsa (arm64). CUDA 11.x and 12.x are
not available for Debian 13 in NVIDIA's apt repo and are out of scope for this image.

### cuDNN

Two cudnn-flavored variants are published alongside the base variants:

- `dhi.io/nvidia-cuda:13.2-cudnn` (runtime + cuDNN .so libraries)
- `dhi.io/nvidia-cuda:13.2-cudnn-dev` (dev + cuDNN libraries + headers)

NVIDIA's Debian 13 cuDNN apt repository is gated behind developer-portal authentication, so cuDNN cannot be installed
via apt in the build pipeline. The cudnn variants instead extract the cuDNN `.so` files (and headers, for dev) from
NVIDIA's official `nvidia/cuda:<version>-cudnn-{runtime,devel}-ubuntu22.04` images on Docker Hub (mirrored on
`nvcr.io/nvidia/cuda`) via OCI artifact, along with the `NGC-DL-CONTAINER-LICENSE` file. The binaries are byte-identical
to NVIDIA's apt-shipped `libcudnn9-cuda-13` package. The build also copies the package's dpkg control stanza into
`/var/lib/dpkg/status.d/`, so cuDNN appears in the image SBOM and scan results as the `libcudnn9-cuda-13` package rather
than as unattributed library files.

If you only need cuDNN for a Python workload, installing `nvidia-cudnn-cu13` from your Python application's requirements
file is also a working path (the same mechanism the upstream PyTorch wheels use). The dev variant ships `apt` but not
pip or Python, so add them first in a `-dev` build stage (`apt-get install -y python3-pip`), install the wheel, then
copy the result into a runtime stage. The base runtime variant has no shell or package manager, so nothing can be
`pip install`-ed against it directly.

cuDNN libraries land at the Debian multiarch path (`/usr/lib/x86_64-linux-gnu/` on amd64, `/usr/lib/aarch64-linux-gnu/`
on arm64), not under `/usr/local/cuda/lib64/`. The dynamic linker searches the multiarch path by default, but build
scripts that hardcode a CUDA toolkit subdirectory (some CMake `find_package(CUDNN)` configs do) need to be pointed at
the multiarch path. The `NGC-DL-CONTAINER-LICENSE` file is at the filesystem root, not under `/usr/share/doc/`;
license-scanning tooling that walks conventional paths may need a hint.

### Migrate from upstream nvidia/cuda

To migrate from `nvidia/cuda:<tag>` or `nvcr.io/nvidia/cuda:<tag>`, update the base image reference in your Dockerfile.

```diff
- FROM nvidia/cuda:13.2.1-runtime-ubuntu22.04
+ FROM dhi.io/nvidia-cuda:13.2
```

```diff
- FROM nvidia/cuda:13.2.1-devel-ubuntu22.04
+ FROM dhi.io/nvidia-cuda:13.2-dev
```

```diff
- FROM nvidia/cuda:13.2.1-cudnn-runtime-ubuntu22.04
+ FROM dhi.io/nvidia-cuda:13.2-cudnn
```

```diff
- FROM nvidia/cuda:13.2.1-cudnn-devel-ubuntu22.04
+ FROM dhi.io/nvidia-cuda:13.2-cudnn-dev
```

The standard `/usr/local/cuda` symlink is in place, so application paths that reference it continue to work without
changes.

### CUDA-specific troubleshooting

**`nvidia-smi: command not found`** -- `nvidia-smi` is provided by the NVIDIA driver on the host, not by the container.
Confirm the NVIDIA Container Toolkit is installed (`apt-get install nvidia-container-toolkit`) and that `--gpus all` is
passed to `docker run`.

**`CUDA driver version is insufficient for CUDA runtime version`** -- The host's NVIDIA driver is older than the minimum
required for this CUDA version. Update the host driver or use an older CUDA image variant.

**`nvidia-smi` reports a lower CUDA version than the image** -- `nvidia-smi`'s "CUDA Version" column reflects the
maximum CUDA version the host's driver supports, not the toolkit version in the image. For example, driver 580.x (max
CUDA 13.0) with this image (CUDA 13.2) shows 13.0 while `cudaRuntimeGetVersion()` returns 13020. Basic CUDA calls still
work, but 13.2-specific APIs that require a newer driver fail at runtime.

**`which: command not found` in the dev variant** -- Use `command -v <name>` instead. The dev variant does not ship
`debianutils`'s `which` binary; upstream `nvidia/cuda:<tag>-devel-ubuntu22.04` includes it by default.

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
