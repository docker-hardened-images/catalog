## Prerequisites

- Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
  organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
  repository**, and then follow the on-screen instructions.
- To use the code snippets in this guide, replace `<your-namespace>` with your organization's namespace and `<tag>` with
  the image variant you want to run (for example, `3.32-debian13`).

## What's included in this Calico API Server image

- apiserver - Aggregated extension API server binary at `/code/apiserver`

## When to use this image

Use this image only when Calico runs in **legacy API server mode** (internal `crd.projectcalico.org/v1` CRDs with API
aggregation). Calico 3.32 and later prefer **native `projectcalico.org/v3` CRDs**; on those clusters `kubectl` talks to
Calico APIs directly and this container image is not deployed.

While the broader Calico DHI image set is being completed, keep this image for backwards-compatible clusters.
Chart-level integration tests against the Tigera Operator are planned once companion Calico images are published.

## Deploy in legacy API server mode

Calico API Server is not a standalone application. It runs inside Kubernetes after Calico networking is already
installed with the **Kubernetes API datastore** (`DATASTORE_TYPE=kubernetes`). It registers the `projectcalico.org/v3`
API group with kube-apiserver through
[API aggregation](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/apiserver-aggregation/).

Follow the upstream guide:
[Enable kubectl to manage Calico APIs](https://docs.tigera.io/calico/latest/operations/install-apiserver).

This guide shows how to use the **Docker Hardened Image** in that flow. It does not walk through installing Calico from
the Tigera Operator Helm chart.

### Replace the upstream container image

Upstream manifests and the operator use `quay.io/calico/apiserver:v<calico-version>`. Point the Deployment at your
mirrored DHI image instead:

```text
dhi.io/<your-namespace>/calico-apiserver:<tag>
```

DHI tags use the Calico version without a `v` prefix (for example, `3.32.0-debian13`). Operator-built image references
often use a `v`-prefixed version in the pod spec (for example, `v3.32.0`). Match the tag format your Tigera Operator
`Installation` CR expects: `<registry><imagePath>/<imagePrefix>apiserver:v<version>`.

### Operator-managed Calico (image override only)

If Tigera Operator already manages Calico on the cluster, you do not reinstall Calico from this guide. Configure the
existing `Installation` CR so **all** Calico component images resolve to DHI, then enable the aggregated API server.

The Installation CR supports three fields:

- `registry` - Docker registry URL (must end with `/`)
- `imagePath` - Path between registry and image name
- `imagePrefix` - Prefix before each component name (`calico-` for DHI)

Image reference format: `<registry><imagePath>/<imagePrefix><component>:v<version>`

Example fragment (adjust registry and paths for your mirror):

```yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  registry: dhi.io/
  imagePath: dhi
  imagePrefix: calico-
```

Create the `APIServer` CR so the operator deploys the aggregated server (legacy mode):

```yaml
apiVersion: operator.tigera.io/v1
kind: APIServer
metadata:
  name: default
spec: {}
```

```bash
kubectl apply -f apiserver.yaml
kubectl get tigerastatus apiserver
```

On Calico 3.32+ with native v3 CRDs, the same `APIServer` CR deploys admission webhooks instead of this
`calico-apiserver` Deployment.

## Common Calico API Server use cases

### kubectl management of Calico APIs

After installation, manage Calico configuration with `kubectl` against `projectcalico.org/v3` resources (for example,
`kubectl get ippools`, `kubectl get networkpolicies.projectcalico.org`).

### Server-side validation

The aggregated API server applies validation and defaulting for Calico resources so clients do not need `calicoctl` for
create and update operations.

### Legacy clusters during migration

Clusters moving from `calicoctl` and internal CRDs toward native v3 CRDs may run this image until aggregation is no
longer required.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

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

For Calico API Server, migration on a running cluster means changing the Deployment image (or `Installation` CR registry
fields) from `quay.io/calico/apiserver` to your mirrored `dhi.io/<your-namespace>/calico-apiserver:<tag>` and rolling
the Deployment.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

For a running API server pod:

```bash
kubectl logs -n calico-apiserver deployment/calico-apiserver
kubectl describe pod -n calico-apiserver -l apiserver=true
```

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

The process reads TLS material from `/code/apiserver.local.config/certificates` (typically from a mounted Secret).

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The default
secure port `5443` is above this threshold. To avoid issues on other ports, configure your application to listen on port
1025 or higher inside the container, even if you map it to a lower port on the host.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. The calico-apiserver
image entry point is `/code/apiserver`. Use `docker inspect` to verify entry points before overriding `command` or
`args` in a Deployment.
