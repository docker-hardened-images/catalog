# k8s-cc-manager Guides

## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/k8s-cc-manager:<tag>`
- Mirrored image: `<your-namespace>/dhi-k8s-cc-manager:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this k8s-cc-manager image

This Docker Hardened k8s-cc-manager image includes:

- `k8s-cc-manager` - the Python CC manager application (`/app/main.py`), which watches the node CC-mode label and drives
  GPU CC/PPCIe mode changes.
- `gpu-admin-tools` - the vendored NVIDIA GPU administration library at `/app/gpu-admin-tools`, used to query and set
  CC/PPCIe mode and to reset GPUs over PCI.
- A Python 3.13 runtime and virtual environment at `/app/.venv`, with the Kubernetes Python client installed.
- `busybox`, which provides `/bin/rm` for the GPU Operator preStop hook.

The entry point is the virtual-environment Python running the application: `/app/.venv/bin/python /app/main.py`.

## Deploy k8s-cc-manager

k8s-cc-manager is designed to run as a Kubernetes DaemonSet on GPU nodes, normally deployed and managed by the NVIDIA
GPU Operator. Replace `<version>` with the DHI release you want to run and append `-dev` only when you need the
development variant.

### Root and privileged requirement

Unlike most Docker Hardened Images, this image runs as **root** and must run **privileged**. The manager pokes GPU PCI
registers and resets GPUs through `gpu-admin-tools`, and it reads host confidential-computing state from `/sys`. A
typical pod spec therefore needs:

- `securityContext.privileged: true` on the container.
- Host mounts for `/sys` and `/dev`.
- A ServiceAccount with permission to `get`, `list`, `watch`, and `patch` nodes (and to list pods in the GPU Operator
  namespace when component eviction is enabled).

Because the image already runs as root, there is no `-compat` variant; use the runtime tag directly.

### Configuration

The manager is configured through environment variables. Set them in the DaemonSet pod spec:

| Variable                    | Required | Default                                         | Description                                                   |
| --------------------------- | -------- | ----------------------------------------------- | ------------------------------------------------------------- |
| `NODE_NAME`                 | Yes      | -                                               | Node name, normally injected via `fieldRef: spec.nodeName`.   |
| `DEFAULT_CC_MODE`           | No       | `on`                                            | CC mode applied when the `nvidia.com/cc.mode` label is unset. |
| `EVICT_OPERATOR_COMPONENTS` | No       | `true`                                          | Evict GPU Operator components before changing CC mode.        |
| `OPERATOR_NAMESPACE`        | No       | `gpu-operator`                                  | Namespace where the GPU Operator is deployed.                 |
| `CC_READINESS_FILE`         | No       | `/run/nvidia/validations/.cc-manager-ctr-ready` | Readiness file created once the manager has applied the mode. |
| `KUBECONFIG`                | No       | (in-cluster)                                    | Path to a kubeconfig for out-of-cluster testing.              |

These defaults come from the application itself, so the image does not hardcode them; set only what you need to override
in the pod spec.

### Node labels

Set the CC mode on a node with a label:

```bash
# Supported values: on, off, devtools, ppcie
kubectl label node <node-name> nvidia.com/cc.mode=on --overwrite
```

The manager reports status back on the node:

```bash
kubectl get node <node-name> -o jsonpath='{.metadata.labels.nvidia\.com/cc\.mode\.state}'
```

### Inspecting the image

Because this image starts a long-running watch that requires `NODE_NAME` and real GPU hardware, use `--help` to inspect
the command-line interface:

```bash
# Runtime variant (no shell) - print CLI help
docker run --rm dhi.io/k8s-cc-manager:<tag> --help

# Dev variant (includes a shell)
docker run --rm --entrypoint /app/.venv/bin/python dhi.io/k8s-cc-manager:<tag>-dev /app/main.py --help
```

## Common k8s-cc-manager use cases

- **Confidential Computing on GPUs**: enable CC mode so GPU workloads run inside a trusted execution environment on
  supported hosts (Intel TDX or AMD SEV-SNP).
- **Protected PCIe (multi-GPU)**: enable PPCIe mode across GPUs and NVSwitches in an NVLink fabric.
- **GPU Operator integration**: run alongside the NVIDIA GPU Operator, which manages the DaemonSet and coordinates
  component eviction during mode changes.

For configuration details, refer to the [upstream documentation](https://github.com/NVIDIA/k8s-cc-manager).

## Non-hardened images vs. Docker Hardened Images

When migrating from the upstream NVIDIA k8s-cc-manager image:

| Feature         | Published upstream NVIDIA image                     | Docker Hardened k8s-cc-manager         |
| --------------- | --------------------------------------------------- | -------------------------------------- |
| Image reference | `nvcr.io/nvidia/cloud-native/k8s-cc-manager:v0.4.0` | `dhi.io/k8s-cc-manager:<version>`      |
| User            | root (0:0)                                          | root (0:0) - required, runs privileged |
| Shell           | No                                                  | No (use `-dev` variant)                |
| Package manager | No                                                  | No package manager in runtime variants |
| Tag format      | `v0.4.0`                                            | `<version>` (no 'v' prefix)            |
| Attack surface  | Larger due to additional utilities                  | Minimal, only essential components     |
| Debugging       | Traditional shell debugging                         | Use Docker Debug or the `-dev` variant |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. For this image the runtime variant runs as root
  and privileged because it manages GPU hardware directly. These images:

  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants include `dev` in the tag name and are intended for use in the first stage of a multi-stage
  Dockerfile. These images:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or extend the application

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Troubleshooting

### General debugging

The hardened image intended for runtime does not contain a shell nor any tools for debugging. The recommended method for
debugging is to use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to the container, or
to run the `-dev` variant which includes a shell.

### Container exits immediately with a NODE_NAME error

The manager requires `NODE_NAME` and exits with a non-zero code if it is not set. In a DaemonSet, inject it via a
`fieldRef`:

```yaml
env:
  - name: NODE_NAME
    valueFrom:
      fieldRef:
        fieldPath: spec.nodeName
```

### GPU access

The manager must be able to reach GPU devices and host CC state. Ensure the container runs privileged and that host
`/sys` and `/dev` are mounted; otherwise mode queries and resets fail.

### Entry point

Docker Hardened Images may have different entry points than other images. Use `docker inspect` to inspect the entry
point and update your deployment if necessary. This image's entry point is `/app/.venv/bin/python /app/main.py`.
