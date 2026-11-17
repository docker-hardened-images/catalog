## How to use this image

This image is the GPU Operator's container-toolkit operand. It is normally deployed by the NVIDIA GPU Operator as a
privileged DaemonSet, not run directly.

### What's included

- `nvidia-ctk-installer` (entrypoint, also reachable as `nvidia-toolkit`): installs the toolkit onto the host and
  configures the node's container runtime.
- `/artifacts/deb` and `/artifacts/rpm`: pre-extracted package trees the installer copies from — the toolkit binaries
  (`nvidia-ctk`, `nvidia-cdi-hook`, the `nvidia-container-runtime` shims, `nvidia-container-runtime-hook`) plus
  `nvidia-container-cli` and the `libnvidia-container` libraries.
- A minimal shell layer (`sh`, `bash`, `cat`, `sleep`) because the GPU Operator's entrypoint script requires it:
  operator releases up to v25.3 ship the script with a `bash` shebang, v25.10 and later with `sh`.

### Use with the NVIDIA GPU Operator

Point the operator's `ClusterPolicy` at this image:

```yaml
apiVersion: nvidia.com/v1
kind: ClusterPolicy
metadata:
  name: cluster-policy
spec:
  toolkit:
    enabled: true
    repository: dhi.io
    image: nvidia-container-toolkit
    version: "<tag>"
```

Replace `<tag>` with the desired image tag, and `dhi.io` with your mirror namespace if you mirror Docker Hardened
Images. The operator's entrypoint script execs the legacy `nvidia-toolkit` name, which this image provides on `PATH`.

### Run a one-shot install manually

The installer copies the toolkit from the staged package trees into a target directory and exits when `--no-daemon` is
set:

```console
$ docker run --rm dhi.io/nvidia-container-toolkit:<tag> \
    --no-daemon --restart-mode=none \
    --toolkit-install-dir=/tmp/toolkit \
    --toolkit-source-root=/artifacts/deb \
    --pid-file=/tmp/toolkit.pid \
    --config=/tmp/daemon.json --create-device-nodes=none --enable-nri-plugin=false
```

Replace `<tag>` with the desired tag. On a real node the install directory and runtime configuration paths are host
mounts supplied by the GPU Operator.

### Root and privileged requirement

The operand installs files onto the host (`/usr/local/nvidia`) and signals the node's container runtime, so the GPU
Operator runs it privileged with `hostPID`, and the image's default user is root. It cannot run as a nonroot container;
this matches the upstream NVIDIA operand.

### Host requirements

The staged toolkit binaries are built on Debian 13 and require glibc 2.38 or newer on the node receiving the install
(for example Debian 13 or Ubuntu 24.04). Both `deb` and `rpm` host package types are supported: the installer
auto-detects the host type and reads `/artifacts/deb` or `/artifacts/rpm` accordingly (`TOOLKIT_PACKAGE_TYPE` overrides
the detection).

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user (this operand image runs as root by design; see above)
  - Do not include a package manager (this image's runtime keeps a minimal shell layer for the GPU Operator's entrypoint
    script)
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

  **`nvidia-container-toolkit` is an exception:** the operand's own binaries perform no cryptography, so its FIPS
  variants differ from the runtime variants only in the OS-level OpenSSL FIPS provider they ship. The toolkit payload
  staged under `/artifacts` is the same build in every variant; once the installer copies it onto the node, it runs
  outside this image, under the host's own libraries.

## Migrate to a Docker Hardened Image

To migrate to a Docker Hardened Image, update the image reference in your Helm values or Kubernetes manifests to the
hardened `nvidia-container-toolkit` image. The GPU Operator exposes the toolkit operand via the `ClusterPolicy`
`toolkit.repository`, `toolkit.image`, and `toolkit.version` fields (or the matching Helm chart values); point those at
the mirrored hardened repository and tag.

| Item            | Migration note                                                                                                                                                             |
| :-------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Image reference | Replace `nvcr.io/nvidia/k8s/container-toolkit` with the hardened `dhi.io/nvidia-container-toolkit` (or your mirror) in the `toolkit` fields.                               |
| Root user       | The image runs as root, matching the upstream operand; the GPU Operator deploys it privileged with `hostPID`.                                                              |
| Shell           | The runtime image ships `sh` and `bash` (the operator's entrypoint script needs them) but no package manager. Use the `dev` variant for Docker Debug-free interactive use. |
| Entry point     | The entry point is `/work/nvidia-ctk-installer`; the legacy `nvidia-toolkit` name resolves via `PATH`.                                                                     |
| Host glibc      | The staged toolkit payload requires glibc 2.38 or newer on the node (Debian 13, Ubuntu 24.04, or newer). Nodes on older glibc lines need the upstream NVIDIA operand.      |

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened runtime image ships only the minimal shell layer the GPU Operator's entrypoint requires and no debugging
tools. The recommended method for debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default, image variants intended for runtime run as the nonroot user. This operand image runs as root by design (it
writes host-mounted paths); ensure your pod security policy allows the GPU Operator's privileged toolkit DaemonSet.

### Minimal shell

The runtime variant keeps `sh` and `bash` for the GPU Operator's entrypoint script but no other shell tooling or package
manager. Use `dev` images to run shell commands interactively, and Docker Debug for interactive debugging.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your manifests if necessary.
