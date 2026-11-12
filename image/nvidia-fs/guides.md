## How to use this image

This image is the NVIDIA GPU Operator's GPUDirect Storage sidecar. When `gds.enabled` is set, the operator runs it next
to the driver container it manages: it compiles the `nvidia-fs` kernel module for the node's kernel (on OpenShift the
Driver Toolkit compiles it), loads it, creates its device nodes and unloads the module when the pod stops, unless it is
in use. It runs privileged and as root because it loads a module into the host kernel.

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/nvidia-fs:<tag>`
- Mirrored image: `<your-namespace>/dhi-nvidia-fs:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Use with the NVIDIA GPU Operator

The operator runs the sidecar only next to a driver container it manages (`driver.enabled: true` or an `NVIDIADriver`
resource) and refuses it with precompiled driver images. It pulls `<repository>/<image>:<version>-<node OS>`, and this
image publishes the upstream image's node OS tags with a `v` before the version, for example `v<version>-ubuntu24.04`,
`v<version>-rhcos4.18` and, for OpenShift 4.19 and later, `v<version>-rhel9`. Set `version` to `v<version>`, where
`<version>` is the release in this image's version tag. It can differ from the release the upstream setting names, and
this image publishes node OS tags only for its own release.

NVIDIA supports `nvidia-fs` 2.17.5 and newer only with the NVIDIA open kernel modules, so set `kernelModuleType` to
`open`. With a driver the `ClusterPolicy` manages, point the `ClusterPolicy` at this image:

```console
$ kubectl patch clusterpolicies.nvidia.com cluster-policy --type merge -p '{
    "spec": {
      "driver": {"enabled": true, "kernelModuleType": "open"},
      "gds": {"enabled": true, "repository": "dhi.io", "image": "nvidia-fs", "version": "v<version>",
              "imagePullPolicy": "Always"}
    }
  }'
```

The same fields exist as Helm values:
`--set driver.kernelModuleType=open --set gds.enabled=true --set gds.repository=dhi.io --set gds.image=nvidia-fs --set gds.version=v<version> --set gds.imagePullPolicy=Always`.
For a FIPS variant, set `version` to `v<version>-fips`. With a mirror on Docker Hub, set `repository` to your namespace
and `image` to `dhi-nvidia-fs`. With the operator's default pull policy, `IfNotPresent`, a node keeps the copy it
already pulled after this image is rebuilt; `Always` pulls the rebuilt image the next time the sidecar starts. With an
`NVIDIADriver` resource, set `kernelModuleType` and the same `gds` fields on that resource instead.

On OpenShift the operator's Driver Toolkit container compiles the module, as with the upstream image; this image stages
the sources for it and loads the result. Without the Driver Toolkit the module is not built, so RHEL nodes outside
OpenShift are not supported, as with the upstream image.

### Load the module manually

The default `install` command builds the module, loads it, creates the `nvidia-fs0` to `nvidia-fs15` device nodes under
`/run/nvidia/driver/dev` and waits. Stopping the container unloads the module unless it is in use. Do not run it on a
node where the operator's sidecar runs. On a node running the operator's driver container (the build takes about a
minute before the last line appears):

```console
$ docker run -d --name nvidia-fs --privileged -v /run/nvidia:/run/nvidia dhi.io/nvidia-fs:<tag>
$ docker logs nvidia-fs | tail -n 1
Done, now waiting for signal
$ docker stop nvidia-fs
$ docker rm nvidia-fs
```

On a node with the NVIDIA driver installed with DKMS instead, mount the node's `/usr/src`, which holds the driver source
and the kernel headers, in place of the driver container's rootfs:

```console
$ sudo mkdir -p /run/nvidia/driver/dev
$ docker run -d --name nvidia-fs --privileged -v /run/nvidia:/run/nvidia \
    -v /usr/src:/run/nvidia/driver/usr/src:ro dhi.io/nvidia-fs:<tag>
```

An `insmod` error in the log means the module did not load and the container has exited.

### Environment variables

| Variable             | Description                                                                         | Default              | Required |
| -------------------- | ----------------------------------------------------------------------------------- | -------------------- | -------- |
| `NVIDIA_DRIVER_ROOT` | Root of the NVIDIA driver container's filesystem: driver source and kernel headers. | `/run/nvidia/driver` | No       |

### Supported nodes

The module compiles against the `-generic` kernel headers of Ubuntu 22.04, 24.04 and 26.04. OpenShift nodes use the
Driver Toolkit. Loading the module needs a GPU node with the NVIDIA driver loaded.

### Variants

The runtime variants run as root and ship `bash` and a C toolchain (`gcc`, `make`, `binutils`, `kmod`), because they
compile and load the module at start. They ship no package manager or debugging tools and serve no port. The GPU
Operator runs the sidecar privileged with `hostPID`, so the namespace of its driver DaemonSet must admit privileged pods
(Pod Security admission level `privileged`).

The FIPS variants add OpenSSL with its FIPS provider and configuration, and the `ca-certificates` package. The sidecar
performs no cryptography and uses none of them; the `nvidia-fs` module they compile runs in the host kernel, outside
this image.

### Kernel headers not found

`Failed to find kernel headers at <dir>, exiting.` means there are no headers at `<dir>`, by default
`/run/nvidia/driver/usr/src/linux-headers-<release>`, and no module the sidecar built earlier on this node matches the
kernel, the `nvidia-fs` version and the NVIDIA driver. The driver container skips installing the headers when it
restarts with the NVIDIA driver still loaded; the sidecar then loads the module it kept under
`/run/nvidia/nvidia-fs-module-cache`. After a reboot or a driver update it needs the headers again.

### Driver source not found

`cp: cannot stat '/run/nvidia/driver/usr/src/nvidia-'` means the headers were found but no NVIDIA driver source
directory (`nvidia-<version>`) was, under `/run/nvidia/driver/usr/src`. With the operator, the sidecar's command first
waits for `/run/nvidia/driver/usr/src` and the loaded NVIDIA module, so the message mostly appears when the image runs
by hand.

### NVIDIA P2P driver symbols not available

`ERROR: NVIDIA P2P driver symbols not available after waiting` means the `nvidia` kernel module was not loaded within
150 seconds. The module compiled, but `nvidia-fs` loads only on top of the NVIDIA driver; the container exits, and under
the operator it restarts.

## Non-hardened images vs. Docker Hardened Images

- Tags: the upstream image's `<version>-<node OS>` tags with a `v` before the version for this image's own release
  (`v<version>-ubuntu24.04` where upstream has `<version>-ubuntu24.04`), plus `-fips` variants
  (`v<version>-fips-ubuntu24.04`). One image serves every tag.
- No package manager in the runtime variants and no network access at start: the kernel headers come from the driver
  container's rootfs instead of `apt-get install linux-headers-$(uname -r)`.
- Ubuntu FIPS kernels: upstream reads `UBUNTU_PRO_TOKEN` to install the headers of a FIPS kernel from Ubuntu Pro. This
  image does not read it, because the driver container reads the same token and installs those headers in its rootfs.
- Debian base instead of NVIDIA's CUDA base image: no CUDA runtime or `git` is shipped, and none of the CUDA base's
  environment variables (`NVIDIA_VISIBLE_DEVICES`, `NVIDIA_REQUIRE_CUDA`, `LD_LIBRARY_PATH`, ...), nor upstream's
  `TARGETARCH`, are set. The sidecar uses none of them. `GDS_VERSION` is set, as upstream sets it, to the `nvidia-fs`
  release, which a module this image builds reports in `/proc/driver/nvidia-fs/stats`.
- Sources: the `nvidia-fs` build tree is at `/usr/src/nvidia-fs-<version>` instead of a git clone at
  `/usr/local/gds-nvidia-fs`, and the module is built inside it.
- One image for Ubuntu and OpenShift nodes: `ocp_dtk_entrypoint`, which upstream ships in its separate `rhel9` image, is
  the same script as `nvidia-gds-driver` here, so the operator's OpenShift command works unchanged.
- Compiler: the module is built with the image's gcc 14, or with `gcc-13` when the kernel's build tree asks for it;
  upstream ships a different gcc in each Ubuntu image (13 on 24.04, 15 on 26.04). When the tree asks for a compiler the
  image does not ship, gcc 14 builds it and the log says so.
- Restarts: the module the sidecar last built is kept under `/run/nvidia/nvidia-fs-module-cache` on the node and reused
  when a restart finds no kernel headers for the same NVIDIA driver. Upstream installs the headers with `apt-get` at
  every start.
- `/bin/sh` is `bash`; upstream's is `dash`.

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
