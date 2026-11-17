## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/ollama:<tag>`
- Mirrored image: `<your-namespace>/dhi-ollama:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Ollama image

This Docker Hardened Image ships the `ollama` binary at `/usr/bin/ollama` and its inference helper, the `llama-server`
binary (with the `ggml`/`llama` shared libraries), at `/usr/lib/ollama`. The image serves the Ollama HTTP API on port
`11434`. The default tags run CPU inference. The `-cuda` flavor (Debian 13 only) adds the CUDA backend for NVIDIA GPUs;
ROCm, Vulkan, and Jetson backends are not included.

## Start Ollama

```console
$ docker run --rm -p 11434:11434 \
  dhi.io/ollama:<version>
```

Verify the server is running:

```console
$ curl http://localhost:11434/
Ollama is running
```

Pull and run a model against the running server (from another terminal, using the upstream `ollama` CLI or the HTTP
API):

```console
$ curl http://localhost:11434/api/pull -d '{"model": "llama3.2"}'
```

```console
$ curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Why is the sky blue?"
}'
```

### Persist models across container restarts

Ollama stores downloaded models under `$HOME/.ollama/models` (`HOME=/home/ollama` in this image) and generates a
registry-auth keypair at `$HOME/.ollama/id_ed25519` on first run. Neither path is declared as a volume in the image
metadata, so mount a volume at `/home/ollama` to persist models and the keypair across container restarts.

The upstream `ollama/ollama` image runs as root with `HOME=/root`, so it stores models under `/root/.ollama`. If you're
migrating an existing deployment, re-point any volume mounted at `/root/.ollama` to `/home/ollama`, otherwise the mount
won't match this image's `HOME` and your existing models will not be found.

```console
$ docker run --rm -p 11434:11434 \
  -v ollama-data:/home/ollama \
  dhi.io/ollama:<version>
```

## Run with an NVIDIA GPU

The `-cuda` flavor ships the CUDA 13.2 backend and runtime libraries. The host needs the NVIDIA driver and the NVIDIA
Container Toolkit. Pass `--gpus all` to expose GPU devices to the container.

```console
$ docker run --rm --gpus all -p 11434:11434 \
  dhi.io/ollama:<version>-debian13-cuda
```

Without `--gpus all`, or on a host without an NVIDIA GPU, the `-cuda` flavor falls back to CPU inference. The
`-cuda-fips` and `-cuda-fips-dev` tags combine the CUDA backend with the FIPS variant described below.

## Docker Hardened Image (DHI) vs Official Docker image

| Feature             | DOI (`ollama/ollama`)           | DHI (`dhi.io/ollama`)                                                                        |
| ------------------- | ------------------------------- | -------------------------------------------------------------------------------------------- |
| User                | root                            | `nonroot` (runtime/FIPS)                                                                     |
| Shell               | Yes                             | No (runtime/FIPS)                                                                            |
| Package manager     | Yes (apt)                       | No (runtime/FIPS)                                                                            |
| Entrypoint          | `ENTRYPOINT ["/bin/ollama"]`    | `ENTRYPOINT ["/usr/bin/ollama"]`                                                             |
| Zero CVE commitment | No                              | Yes                                                                                          |
| FIPS variant        | No                              | Yes (Go FIPS toolchain + OpenSSL FIPS provider for STIG)                                     |
| Base OS             | Ubuntu/CUDA/ROCm base images    | Docker Hardened Images (Alpine 3.24 or Debian 13)                                            |
| GPU backends        | CUDA, ROCm, Vulkan, Jetson, MLX | CUDA via the `-cuda` flavor (Debian 13 only); ROCm, Vulkan, Jetson, and MLX are not included |

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

- The `cuda` flavor includes `cuda` in the tag and adds the CUDA backend plus the NVIDIA CUDA runtime libraries for GPU
  inference. It is available for Debian 13 in runtime, build-time, and FIPS variants and requires the NVIDIA Container
  Toolkit on the host.

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
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime.                                                                                                                                                                                                                                             |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |
| GPU backends       | The default tags are CPU-only. Use the `-cuda` flavor with the NVIDIA Container Toolkit (`--gpus all`) for CUDA acceleration. ROCm, Vulkan, and Jetson are not covered.                                                                                                                                                      |

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
   install additional packages in your Dockerfile. To view if a package manager is available for an image variant,
   select the **Tags** tab for this repository. To view what packages are already installed in an image variant, select
   the **Tags** tab for this repository, and then select a tag.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Troubleshooting migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers.

### Permissions

By default image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user, including a mounted volume at `/home/ollama` if you need models to persist.

### Entry point

Docker Hardened Images may have different entry points than the upstream Ollama image. Use `docker inspect` to inspect
entry points and update your deployment if necessary.
