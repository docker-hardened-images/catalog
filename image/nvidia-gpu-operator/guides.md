## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This image runs the `gpu-operator` controller as its entry point. The GPU Operator is designed to run inside a
Kubernetes cluster: it reconciles a `ClusterPolicy` custom resource and manages the NVIDIA driver, container toolkit,
device plugin, feature discovery, DCGM monitoring, and validation components. It requires an in-cluster
`OPERATOR_NAMESPACE` and a reachable Kubernetes API server, so it is normally deployed via the GPU Operator Helm chart
rather than run standalone.

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

The bundled `nvidia-validator` reports its version without a cluster:

```
$ docker run --rm --entrypoint nvidia-validator dhi.io/nvidia-gpu-operator:<tag> --version
```

The image also ships `kubectl` and the `vectorAdd` CUDA validation sample (at `/usr/bin/vectorAdd`); the sample requires
a GPU-enabled node to run.

## What's included

This image bundles the following tools on `PATH` at `/usr/bin`:

- `gpu-operator` - the operator controller (the image entry point)
- `nvidia-validator` - validates driver, container toolkit, device plugin, and CUDA workload readiness on GPU nodes
- `vectorAdd` - the CUDA validation sample the validator runs on a GPU node
- `kubectl` - Kubernetes CLI the operator uses to apply operand manifests

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a package manager (this image's runtime keeps a minimal `sh` for the validation workloads)
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

## Migrate to a Docker Hardened Image

To migrate to a Docker Hardened Image, update the image reference in your Helm values or Kubernetes manifests to the
hardened `nvidia-gpu-operator` image. The GPU Operator Helm chart exposes the operator image via `operator.repository`,
`operator.image`, and `operator.version`; point those at the mirrored hardened repository and tag.

| Item            | Migration note                                                                                                                                                                                |
| :-------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Image reference | Replace `nvcr.io/nvidia/gpu-operator` with the hardened `dhi.io/nvidia-gpu-operator` (or your mirror) in the chart's `operator` and `validator` image fields.                                 |
| Non-root user   | The runtime image runs as the nonroot user (uid 65532), matching the upstream image. Ensure any mounted paths are accessible to that user.                                                    |
| Shell           | The runtime image ships a minimal `sh` (dash) because the validation workloads run via `sh -c`, but no bash and no package manager. Use the `dev` variant for build stages or Docker Debug.   |
| Entry point     | The entry point is `/usr/bin/gpu-operator`. The bundled tools (`nvidia-validator`, `kubectl`, `vectorAdd`) are on `PATH` at `/usr/bin` and can be invoked by name.                            |
| Operand images  | This image hardens the operator (and validator) only. The driver, container toolkit, device plugin, DCGM, and other operand images referenced by the chart remain the upstream NVIDIA images. |

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened runtime image ships only a minimal `sh` (required by the validation workloads) and no debugging tools. The
recommended method for debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default, image variants intended for runtime run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user.

### Minimal shell

The runtime variant keeps a minimal `sh` (dash) for the validation workloads but no other shell tooling or package
manager. Use `dev` images in build stages to run shell commands and then copy any necessary artifacts into the runtime
stage. In addition, use Docker Debug for interactive debugging.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your manifests if necessary.
