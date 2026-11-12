## Prerequisites

- Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
  organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
  repository**, and then follow the on-screen instructions.
- To use the code snippets in this guide, replace `<your-namespace>` with your organization's namespace and `<tag>` with
  the image variant you want to run.

## What's included in this Calico Whisker image

- nginx - Web server that serves the Whisker UI
- Whisker UI - React static assets built from the Project Calico monorepo
- nginx-start.sh - Entrypoint that writes runtime configuration and starts nginx

Whisker listens on port **8081** and uses entrypoint `/usr/bin/nginx-start.sh`, matching upstream `calico/whisker`.

## Deploy with the Tigera Operator

The recommended way to deploy Calico in production is using the
[Tigera Operator](https://docs.tigera.io/calico/latest/getting-started/kubernetes/quickstart). You can override Calico
component images, including Whisker, to use Docker Hardened Images via the Installation custom resource.

Whisker requires the separate `calico/whisker-backend` component for API functionality. Ensure both DHI images are
available in your registry when enabling Whisker.

### Install the Tigera Operator

First, install the Tigera Operator using Helm:

```bash
helm repo add projectcalico https://docs.tigera.io/calico/charts
helm install calico projectcalico/tigera-operator \
  --namespace tigera-operator \
  --create-namespace
```

Enable Whisker in the operator values (or via a `Whisker` custom resource after the operator is running):

```yaml
whisker:
  enabled: true
```

Create an image pull secret in the `tigera-operator` namespace:

```bash
kubectl create secret docker-registry dhi-pull-secret \
  --namespace tigera-operator \
  --docker-server=dhi.io \
  --docker-username=<your-username> \
  --docker-password=<your-token>
```

### Configure the Installation CR

The Tigera Operator uses the Installation custom resource to configure Calico components, including which container
images to use. To use Docker Hardened Images, configure the Installation CR with the correct registry settings.

**Important**: The Installation CR image configuration applies to **all** Calico component images, not just Whisker. The
operator constructs image references using this format: `<registry><imagePath>/<imagePrefix><imageName>:<tag>`

The Installation CR supports three fields for image configuration:

- `registry` - Docker registry URL (must end with `/`). Set to `dhi.io/` for DHI.
- `imagePath` - Path component between registry and image name. Set to `dhi/` for DHI.
- `imagePrefix` - Prefix added to each image name. Set to `calico-` to match DHI image names.

Create an Installation CR with the following configuration:

```yaml
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  imagePullSecrets:
    - name: dhi-pull-secret
  registry: dhi.io/
  imagePath: "dhi"
  imagePrefix: "calico-"
  cni:
    type: Calico
  calicoNetwork:
    bgp: Enabled
```

Save this YAML to a file (e.g., `installation.yaml`) and apply it:

```bash
kubectl apply -f installation.yaml
```

Align the tag with your Calico release version. DHI catalog tags use the upstream Calico version number directly with no
`v` prefix (for example, `3.32.0-debian13`). The Tigera Operator may construct image references with a `v`-prefixed tag
(for example, `v3.32.0-debian13`); mirror or retag images accordingly if your operator configuration requires it.

**Note**: This configuration tells the Tigera Operator to use DHI images for all Calico components. The operator will
continuously reconcile the deployment to match the Installation CR, so it will not revert to upstream images as long as
this configuration is in place. If you only have the Whisker DHI image available, other Calico components may fail to
start with `ImagePullBackOff` until their DHI images are also available in your registry.

## Common Calico Whisker use cases

All examples use the public image `dhi.io/calico-whisker:<tag>`. If you've mirrored the repository, reference your
namespace instead.

### Run the UI locally

Authenticate before pulling:

```console
docker login dhi.io
```

Whisker listens on port 8081 by default:

```console
docker run --rm -p 8081:8081 dhi.io/calico-whisker:<tag>
```

Open http://localhost:8081 in your browser.

### Configure cluster metadata

The entrypoint generates `/etc/config/config.json` from environment variables at startup:

```console
docker run --rm -p 8081:8081 \
  -e CLUSTER_ID="my-cluster" \
  -e CLUSTER_TYPE="kubernetes" \
  -e CALICO_VERSION="3.32.0" \
  -e NOTIFICATIONS="Enabled" \
  -e CALICO_CLOUD_URL="https://www.calicocloud.io/api" \
  dhi.io/calico-whisker:<tag>
```

| Variable           | Description                        | Default                          |
| :----------------- | :--------------------------------- | :------------------------------- |
| `CLUSTER_ID`       | Cluster identifier shown in the UI | (empty)                          |
| `CLUSTER_TYPE`     | Cluster type label                 | (empty)                          |
| `CALICO_VERSION`   | Calico version string              | (empty)                          |
| `NOTIFICATIONS`    | Notifications setting              | `Enabled`                        |
| `CALICO_CLOUD_URL` | Calico Cloud API URL               | `https://www.calicocloud.io/api` |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a non-root user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
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

To migrate from `calico/whisker` to this Docker Hardened Image, update your Tigera Operator `Installation` CR registry
settings as described above. At minimum, ensure the operator resolves `calico-whisker` to your mirrored DHI image and
tag.

| Item               | Migration note                                                                                                                                                              |
| :----------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace `calico/whisker` with `dhi.io/calico-whisker` (or your mirrored equivalent) in operator image configuration.                                                        |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                 |
| Non-root user      | This image runs as UID `10001`, matching upstream `calico/whisker`. Ensure mounted volumes and config paths are writable by that user if you customize the deployment.      |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                  |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                          |
| Ports              | Whisker listens on port **8081** inside the container. Map host traffic to `8081/tcp` in Services and Deployments.                                                          |
| Entry point        | Entrypoint is `/usr/bin/nginx-start.sh`, matching upstream. Pass `test` as the command to validate nginx configuration, as upstream does.                                   |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage. |
| Backend dependency | The UI proxies API traffic to `whisker-backend`. Deploy `calico/whisker-backend` (or its DHI equivalent) alongside this image for full functionality in Kubernetes.         |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Mirror the image to your registry.

   Mirror `dhi/calico-whisker` and any other Calico DHI component images your operator configuration references.

1. Update the Tigera Operator Installation CR.

   Set `registry`, `imagePath`, and `imagePrefix` so the operator pulls `calico-whisker` from your DHI mirror. Enable
   Whisker in operator values or via the `Whisker` CR.

1. Verify the deployment.

   Confirm the Whisker pod serves the UI on port 8081 and that `whisker-backend` is running for API requests.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

This image runs as UID `10001`, matching upstream Whisker. Ensure that necessary files and directories are accessible to
that user. The entrypoint writes `/etc/config/config.json` at startup; the image provides the required directories.

### Privileged ports

Whisker listens on port 8081 inside the container, which is above the privileged port range. No special port binding
configuration is required for non-root execution.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your deployment manifests if necessary. Upstream Whisker
uses `/usr/bin/nginx-start.sh`; this image preserves that entrypoint.

### Backend connectivity

If the UI loads but flow data is missing, verify that `whisker-backend` is deployed and reachable. The nginx
configuration proxies `/whisker-backend/` to the backend service in the cluster.
