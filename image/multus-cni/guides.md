## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this multus-cni image

This Docker Hardened multus-cni image includes:

- `multus` - The thin CNI plugin binary invoked directly by the container runtime (thin plugin mode).
- `multus-daemon` - The Multus daemon that serves CNI requests over a Unix domain socket (thick plugin mode).
- `multus-shim` - Lightweight CNI shim that forwards runtime requests to `multus-daemon` (thick plugin mode).
- `install_multus` - Installer that copies the Multus binaries onto the host CNI bin directory.
- `thin_entrypoint` - Default entrypoint for thin plugin deployments; installs the plugin binary and generates its CNI
  configuration on the host.
- `kubeconfig_generator` - Generates the kubeconfig Multus uses to reach the Kubernetes API from the node.
- `cert-approver` - Approves kubelet-style certificate signing requests when per-node certificates are enabled.
- `passthru` - A no-op delegate CNI plugin, useful for testing delegate chains.

## Start a multus-cni container

`multus-cni` is a Kubernetes CNI meta-plugin. It's designed to run as a pod in a node DaemonSet, not as a standalone
long-running service, so the default entrypoint (`thin_entrypoint`) expects the host CNI directories described in
[Deploy multus-cni as a Kubernetes DaemonSet](#deploy-multus-cni-as-a-kubernetes-daemonset) to be mounted into the
container.

To check the version of the `multus` plugin binary bundled in the image:

```bash
docker run --rm --entrypoint /usr/bin/multus dhi.io/multus-cni:<tag> --version
```

## Deploy multus-cni as a Kubernetes DaemonSet

Multus is deployed as a DaemonSet so that the CNI plugin and its configuration are installed on every node in the
cluster. It supports two deployment modes.

Kubernetes nodes don't inherit credentials from `docker login` on your workstation. Unless your cluster already has
node-level credentials for `dhi.io`, create an image pull secret in `kube-system` before deploying Multus:

```bash
kubectl create secret docker-registry dhi-pull-secret \
  --docker-server=dhi.io \
  --docker-username='<Docker username>' \
  --docker-password='<Docker personal access token>' \
  --namespace kube-system \
  --dry-run=client -o yaml \
  | kubectl apply -f -
```

If your cluster uses node-level registry credentials, omit both the secret creation and the
`kubectl patch serviceaccount` command in the deployment examples.

### Thin plugin mode

In thin plugin mode, the `thin_entrypoint` process runs in every DaemonSet pod. It copies the `multus` binary to the
node's `/opt/cni/bin` and renders `/etc/cni/net.d/00-multus.conf` or `/etc/cni/net.d/00-multus.conflist`, depending on
the CNI version of the alphabetically first existing CNI configuration on the node (the "default network"). Apply the
upstream thin DaemonSet manifest, replace the container images with the Docker Hardened Image, attach the pull secret,
and explicitly run the host-modifying containers as root:

```bash
VERSION='<version>'
DHI_TAG='<tag>'

curl -fsSL "https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/v${VERSION}/deployments/multus-daemonset.yml" \
  | sed "s#ghcr.io/k8snetworkplumbingwg/multus-cni:snapshot#dhi.io/multus-cni:${DHI_TAG}#g" \
  | kubectl apply -f -

kubectl patch serviceaccount multus --namespace kube-system --type=merge \
  --patch '{"imagePullSecrets":[{"name":"dhi-pull-secret"}]}'

kubectl patch daemonset kube-multus-ds --namespace kube-system --type=json \
  --patch='[
    {"op":"add","path":"/spec/template/spec/containers/0/securityContext/runAsUser","value":0},
    {"op":"add","path":"/spec/template/spec/initContainers/0/securityContext/runAsUser","value":0}
  ]'
```

The manifest's `kube-multus` container runs with `command: ["/thin_entrypoint"]` and `securityContext.privileged: true`,
and its `install-multus-binary` init container runs `["/install_multus", "--type", "thin"]`. Both paths resolve to the
same packaged `thin_entrypoint` and `install_multus` binaries in this image. The explicit `runAsUser: 0` settings are
required because privileged containers still retain the image's default uid, and both containers write to root-owned
host paths.

Validate the installation once the DaemonSet pods are running:

```bash
kubectl get pods --all-namespaces | grep -i multus
```

### Thick plugin mode

Thick plugin mode splits Multus into a long-running `multus-daemon` server and a `multus-shim` CNI client, adding
features such as metrics at the cost of a persistent per-node process. Apply the upstream thick DaemonSet manifest with
the image reference and required Kubernetes settings applied:

```bash
VERSION='<version>'
DHI_TAG='<tag>'

curl -fsSL "https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/v${VERSION}/deployments/multus-daemonset-thick.yml" \
  | sed "s#ghcr.io/k8snetworkplumbingwg/multus-cni:snapshot-thick#dhi.io/multus-cni:${DHI_TAG}#g" \
  | kubectl apply -f -

kubectl patch serviceaccount multus --namespace kube-system --type=merge \
  --patch '{"imagePullSecrets":[{"name":"dhi-pull-secret"}]}'

kubectl patch daemonset kube-multus-ds --namespace kube-system --type=json \
  --patch='[
    {"op":"add","path":"/spec/template/spec/containers/0/securityContext/runAsUser","value":0},
    {"op":"add","path":"/spec/template/spec/initContainers/0/securityContext/runAsUser","value":0}
  ]'
```

Here the `kube-multus` container runs `command: ["/usr/src/multus-cni/bin/multus-daemon"]` and the
`install-multus-binary` init container runs
`["/usr/src/multus-cni/bin/install_multus", "-d", "/host/opt/cni/bin", "-t", "thick"]`. Both paths are packaged as
symlinks to the same binaries in this image.

### Advanced configuration

For per-node certificate rotation with `cert-approver`, generating a node kubeconfig with `kubeconfig_generator`, DRA
(Dynamic Resource Allocation) integration, and Multus daemon metrics, see the upstream
[How to use](https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/how-to-use.md) and
[Thick plugin](https://github.com/k8snetworkplumbingwg/multus-cni/blob/master/docs/thick-plugin.md) documentation.

## Non-hardened images vs. Docker Hardened Images

- The DHI runtime variant runs as the `nonroot` user by default, while upstream `multus-cni` images run as root.
  Kubernetes retains the image's default uid even when `securityContext.privileged: true` is set, so deployments that
  write to root-owned host paths such as `/opt/cni/bin` and `/etc/cni/net.d` must explicitly set `runAsUser: 0`, as in
  the examples above.
- Upstream images expose the same binaries at multiple filesystem paths for compatibility with existing manifests:
  `/thin_entrypoint`, `/install_multus`, `/kubeconfig_generator`, and `/cert-approver` (from the upstream thin image),
  and `/usr/src/multus-cni/bin/<binary>` for all eight binaries (from both upstream images). This image preserves both
  path layouts as symlinks to the packaged binaries in `/usr/bin`, so existing DaemonSet command paths continue to work.
- The runtime variant has no shell. The upstream thick image includes a shell; the upstream thin image is distroless and
  does not.

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
