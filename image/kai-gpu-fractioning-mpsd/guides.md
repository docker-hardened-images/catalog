## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kai-gpu-fractioning-mpsd:<tag>`
- Mirrored image: `<your-namespace>/dhi-kai-gpu-fractioning-mpsd:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a kai-gpu-fractioning-mpsd image

mpsd is not started by hand: the GPU Fractioning operator creates it as the `gpu-fractioning-mpsd` DaemonSet on nodes
labelled `nvidia.com/gpu.present=true`. Install the upstream Helm chart and point its `images.mpsd` values at this
image. Replace `<tag>` with the image variant you want to run.

### Install with the upstream Helm chart

The chart passes the pull secret to the operator only, so the DaemonSet pods use a service account that already carries
it. Create that service account before you install the chart, because Kubernetes adds a service account's pull secrets
to a pod only when the pod is created:

```bash
$ kubectl create namespace gpu-fractioning
$ kubectl -n gpu-fractioning create secret docker-registry dhi-pull-secret \
  --docker-server=dhi.io --docker-username=<username> --docker-password=<token>
$ kubectl -n gpu-fractioning create serviceaccount gpu-fractioning-daemon
$ kubectl -n gpu-fractioning patch serviceaccount gpu-fractioning-daemon \
  -p '{"imagePullSecrets":[{"name":"dhi-pull-secret"}]}'
```

Docker Hardened Images tags don't carry the `v` prefix that the upstream tags do. The Debian 13 runtime and FIPS
variants also publish `v0.1.8` and `v0.1.8-fips`, the tags the chart resolves by default. For any other variant, set the
tag explicitly:

```bash
$ helm install gpu-fractioning oci://ghcr.io/kai-scheduler/gpu-fractioning \
  --version v0.1.8 --namespace gpu-fractioning \
  --set 'imagePullSecrets[0].name=dhi-pull-secret' \
  --set daemonServiceAccount.create=false \
  --set daemonServiceAccount.name=gpu-fractioning-daemon \
  --set images.mpsd.repository=dhi.io/kai-gpu-fractioning-mpsd \
  --set images.mpsd.tag=<tag>
```

The nodes need the NVIDIA GPU Operator and an NVIDIA driver of the `r615` branch or newer, as the upstream project
requires.

### Container user

This image runs as root (uid 0), as the upstream image does. mpsd creates its MPS configuration directory under `/etc`
and drives MPS through root-owned host directories. Run as the nonroot user it exits at startup with
`mkdir /etc/nvidia-mps: permission denied`.

### Run mpsd directly

mpsd needs a Kubernetes API server and the NVIDIA runtime, so outside a GPU node it only prints its usage:

```bash
$ docker run --rm dhi.io/kai-gpu-fractioning-mpsd:<tag> -h
```

## Common kai-gpu-fractioning-mpsd use cases

### Check that mpsd is running on a node

The pod's readiness and liveness probes run `test -S` on the MPS control socket, and mpsd records the driver version it
read on the node:

```bash
$ kubectl -n gpu-fractioning get pods -l app.kubernetes.io/component=mpsd
$ kubectl get node <node-name> -o jsonpath='{.metadata.labels.gpu-fractioning\.kai\.scheduler/nvidia-driver-version\.major}'
```

### Select the FIPS image

With `global.fipsMode=on` the chart appends `-fips` to every resolved image tag, so keep `<tag>` without the suffix:

```bash
$ helm install gpu-fractioning oci://ghcr.io/kai-scheduler/gpu-fractioning \
  --version v0.1.8 --namespace gpu-fractioning \
  --set 'imagePullSecrets[0].name=dhi-pull-secret' \
  --set daemonServiceAccount.create=false \
  --set daemonServiceAccount.name=gpu-fractioning-daemon \
  --set images.mpsd.repository=dhi.io/kai-gpu-fractioning-mpsd \
  --set images.mpsd.tag=<tag> --set global.fipsMode=on
```

### FIPS boundary

The FIPS variants cover the Go cryptography linked into the binary. The NVIDIA driver library and the MPS binaries that
the NVIDIA container runtime injects from the host are outside the image and are not part of the FIPS claim.

## Non-hardened images vs. Docker Hardened Images

- Tags have no `v` prefix, so set `images.mpsd.tag` because the chart's default tag is `v`-prefixed. The Debian 13
  runtime and FIPS variants also publish `v0.1.8` and `v0.1.8-fips`.
- The image runs as root, like the upstream image; see [Container user](#container-user).
- The entry point is `/usr/local/bin/kai-gpu-fractioning-mpsd`. The upstream path `/usr/local/bin/mpsd` still resolves
  to the same binary, and the arguments the operator passes are unchanged.
- The image is built on Debian 13 with glibc, `coreutils` for the probes' `test` binary, CA certificates and time zone
  data. It sets `NVIDIA_VISIBLE_DEVICES=all` and `NVIDIA_DRIVER_CAPABILITIES=compute,utility`, as the upstream image
  does.
- The licence text and the third-party attribution file are shipped in `/usr/share/licenses/kai-gpu-fractioning-mpsd/`.
  The upstream path `/THIRD-PARTY.txt` still resolves to the attribution file.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

  > **Note:** Unlike most DHI runtime images, this image runs as **root** (uid 0). See
  > [Container user](#container-user).

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
| Non-root user      | Most non-dev DHI images run as the nonroot user, but this image runs as **root** (uid 0) because mpsd creates its MPS configuration directory under `/etc` and runs MPS on root-owned host directories, so a nonroot mpsd exits at startup. See [Container user](#container-user).                                           |
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

Most runtime image variants run as the nonroot user, but this image runs as root (uid 0); see
[Container user](#container-user). Files and directories you mount are readable by it without extra permissions.

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
