## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this image

This Docker Hardened image contains the Tailscale Kubernetes Operator (`/usr/local/bin/operator`). The operator runs
inside your Kubernetes cluster and reconciles Tailscale resources such as `Connector`, `ProxyClass`, and the
operator-managed Services and Ingresses.

The image does **not** include the `tailscale` or `tailscaled` binaries. Workloads that need the Tailscale daemon (for
example, sidecar proxies the operator generates) use the [`dhi/tailscale`](https://dhi.io/tailscale) image instead.

## Deploy the operator with the official Helm chart

The Tailscale Kubernetes Operator is installed in a cluster with the upstream Helm chart. Override the operator image to
point at the Docker Hardened version:

```bash
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update

helm upgrade --install tailscale-operator tailscale/tailscale-operator \
  --namespace tailscale --create-namespace \
  --set-string oauth.clientId="$TS_CLIENT_ID" \
  --set-string oauth.clientSecret="$TS_CLIENT_SECRET" \
  --set-string operatorConfig.image.repository=dhi.io/tailscale-operator \
  --set-string operatorConfig.image.tag=<tag>
```

Replace `<tag>` with a tag that exists for `dhi.io/tailscale-operator` (for example, `1` or `1-debian13`). See the
[Tailscale Kubernetes Operator install guide](https://tailscale.com/kb/1236/kubernetes-operator) for the full set of
configuration options and how to obtain OAuth client credentials.

## Image variants

The Tailscale Kubernetes Operator Docker Hardened Image provides standard runtime variants optimized for production use.
These images are:

- Designed to run your application in production
- Run as the nonroot user for enhanced security
- Do not include a shell or package manager to minimize attack surface
- Contain only the minimal set of libraries needed to run the Tailscale operator

A `-dev` variant adds a shell, `apt`, and standard development tools for use as a build-time base image in multi-stage
Dockerfiles.

## Migrate to a Docker Hardened Image

The Docker Hardened Tailscale Kubernetes Operator image is a drop-in replacement for `tailscale/k8s-operator`. Update
your Helm values (or manifests) to point `operator.image.repo` / `operator.image.tag` at `dhi.io/tailscale-operator`.

### Migration steps

1. **Update your image reference.**

   Replace the image reference in your Helm values or Kubernetes manifests:

   - From: `tailscale/k8s-operator:<any-tag>` (e.g., `latest`, `unstable`, `v1.96.4`)
   - To: `dhi.io/tailscale-operator:<tag>`

1. **No configuration changes needed.**

   The operator reads the same environment variables, mounts the same OAuth client secret, and watches the same
   Tailscale custom resources as the upstream image.

### General migration considerations

| Item            | Migration note                                                         |
| --------------- | ---------------------------------------------------------------------- |
| Shell access    | No shell in runtime variants, use Docker Debug for troubleshooting     |
| Package manager | No package manager in runtime variants                                 |
| Debugging       | Use Docker Debug or Image Mount instead of traditional shell debugging |

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### No shell

By default, image variants intended for runtime don't contain a shell. Use the `-dev` variant in build stages to run
shell commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug
containers with no shell.
