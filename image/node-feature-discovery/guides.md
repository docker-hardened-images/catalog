## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/node-feature-discovery:<tag>`
- Mirrored image: `<your-namespace>/dhi-node-feature-discovery:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Node Feature Discovery Hardened image

Node Feature Discovery detects hardware features and configuration on Kubernetes nodes. It publishes feature information
as node labels and extended resources so workloads can be scheduled onto compatible nodes.

This Docker Hardened Node Feature Discovery image includes the upstream binaries:

- `nfd-master`
- `nfd-worker`
- `nfd-topology-updater`
- `nfd-gc`
- `kubectl-nfd`
- `nfd`

The image also includes the upstream default worker configuration at
`/etc/kubernetes/node-feature-discovery/nfd-worker.conf`.

The upstream image does not define a default entrypoint or command. Use the Kubernetes manifests or explicitly select
the binary you want to run.

## Check the version

Use `--entrypoint` to run an individual binary:

```bash
$ docker run --rm --entrypoint nfd-worker dhi.io/node-feature-discovery:<tag> -version
nfd-worker v0.18.3
```

## Deploy to Kubernetes

Node Feature Discovery is typically deployed to Kubernetes with the upstream manifests or Helm chart. To use the Docker
Hardened Image, override the image registry, repository, and tag values to point at `dhi.io/node-feature-discovery`.

Create an image pull secret for the DHI registry:

```bash
$ kubectl create secret docker-registry dhi-pull-secret \
    --docker-server=dhi.io \
    --docker-username=<Docker username> \
    --docker-password=<Docker token> \
    --docker-email=<Docker email> \
    --namespace=node-feature-discovery
```

Use a Docker Hub personal access token, not your account password. For more detail, see
[DHI authentication in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/).

See the upstream deployment documentation for current manifests and Helm values:
https://kubernetes-sigs.github.io/node-feature-discovery/stable/get-started/deployment-and-usage.html

## Image variants

Docker Hardened Images publish multiple variants where applicable:

- Runtime variants contain only the application and its runtime dependencies.
- Dev variants include package managers and common debugging tools for development and multi-stage builds.

This image currently publishes Debian 13 runtime and dev variants. It does not currently publish FIPS variants.

## Migrate to a Docker Hardened Image

Replace the upstream image reference with the Docker Hardened Image reference:

| Upstream image                                     | Docker Hardened Image                 |
| -------------------------------------------------- | ------------------------------------- |
| `registry.k8s.io/nfd/node-feature-discovery:<tag>` | `dhi.io/node-feature-discovery:<tag>` |

The Docker Hardened Image follows the upstream image's no-entrypoint behavior and includes the same primary binaries.
Runtime variants are minimal and do not include a shell or package manager. Use a dev variant or Docker Debug when you
need interactive troubleshooting tools.

## Troubleshooting migration

If a command fails with `executable file not found`, confirm that the manifest or Helm values use one of the included
NFD binaries as the command or entrypoint.

If Kubernetes cannot pull the image, confirm that the namespace contains an image pull secret for `dhi.io` and that the
workload references that secret.

For general DHI troubleshooting, see the Docker Hardened Images documentation: https://docs.docker.com/dhi/
