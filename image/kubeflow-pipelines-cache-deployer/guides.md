## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/kubeflow-pipelines-cache-deployer:<tag>`
- Mirrored image: `<your-namespace>/dhi-kubeflow-pipelines-cache-deployer:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What the cache deployer does

This image replaces `ghcr.io/kubeflow/kfp-cache-deployer` from
[Kubeflow Pipelines](https://www.kubeflow.org/docs/components/pipelines/). Kubeflow Pipelines runs it in the
`cache-deployer-deployment` Deployment to install the mutating webhook of the pipelines cache server. The entrypoint,
`/bin/sh /kfp/cache/deployer/deploy-cache-service.sh`, is the same as upstream.

On start, the deployer checks for the MutatingWebhookConfiguration `cache-webhook-<namespace>` and the Secret
`webhook-server-tls`:

- If both exist, it logs `Webhook config and secret are already installed. Sleeping forever.`
- Otherwise, it generates a key with `openssl` and submits the CertificateSigningRequest `cache-server.<namespace>` with
  the `kubernetes.io/kubelet-serving` signer. Then it approves the request, stores `key.pem` and `cert.pem` in the
  Secret, applies the webhook configuration with the cluster CA bundle, and logs
  `Webhook has been installed. Sleeping forever.`

The deployer needs a Kubernetes API server and the upstream RBAC: the ServiceAccount
`kubeflow-pipelines-cache-deployer-sa`, a ClusterRole for CertificateSigningRequests and MutatingWebhookConfigurations,
and a Role for Secrets. Started outside a cluster, it exits with status `1` because `kubectl` cannot reach an API
server.

| Variable                            | Description                                                                                                                                        | Default                                      |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| `NAMESPACE_TO_WATCH`                | Namespace of the webhook configuration and Secret. The upstream manifest sets it from `metadata.namespace`.                                        | `kubeflow`                                   |
| `KFP_CACHE_DEPLOYER_STATE_DIR`      | Directory where each run writes its working files: `webhooks.txt`, `cache_secret.txt`, `ca_cert`, and the rendered webhook manifest. DHI-specific. | `/var/lib/kubeflow-pipelines-cache-deployer` |
| `DEPLOY_CACHE_SERVICE_LIBRARY_MODE` | When `true`, the script only defines its functions and exits without deploying anything. Kubeflow Pipelines 2.18 only.                             | `false`                                      |

## Release lines

Two Kubeflow Pipelines lines are maintained, and each has its own image tags. Use the line that matches your Kubeflow
Pipelines release:

| Kubeflow Pipelines release | Image tags (Debian 13) | Bundled kubectl |
| -------------------------- | ---------------------- | --------------- |
| 2.18                       | `2`, `2.18`, `2.18.0`  | 1.37            |
| 2.17                       | `2.17`, `2.17.3`       | 1.36            |

The floating `2` tag follows the highest line, 2.18. The examples below use 2.18.0. For 2.17.3, use the 2.17.3 tag and
`ref=2.17.3` in the kustomization, and check the webhook as shown below. The 2.17.3 deployer predates the
`DEPLOY_CACHE_SERVICE_LIBRARY_MODE` variable in the table below. Running it with that variable starts a deployment.

## Check the bundled kubectl

The image ships a fixed `kubectl` release. Print its version and compare it with your cluster:

```bash
docker run --rm --entrypoint kubectl dhi.io/kubeflow-pipelines-cache-deployer:2 version --client
```

The Kubernetes [version skew policy](https://kubernetes.io/releases/version-skew-policy/#kubectl) supports `kubectl`
within one minor version of the API server. For example, `kubectl` 1.37 supports API servers 1.36, 1.37, and 1.38. The
upstream image downloaded a `kubectl` that matched the server version at startup. This image never downloads one, so use
it only with clusters inside that range.

## Registry credentials for Kubernetes

Kubernetes nodes do not use your `docker login`, so the deployer pod cannot pull `dhi.io` images without a pull secret.
Create a pull secret in the namespace the deployer runs in, `kubeflow`, from a personal or organization access token
with read-only access to the repositories. Follow Docker's
[Use with Kubernetes](https://docs.docker.com/dhi/how-to/use/#use-with-kubernetes) instructions for the secret. Create
the `kubeflow` namespace first if the platform install has not created it yet:

```bash
kubectl -n kubeflow create secret docker-registry dhi-pull-secret \
  --docker-server=dhi.io \
  --docker-username=<registry user> \
  --docker-password=<access token> \
  --docker-email=<registry email>
```

The kustomization in the next section references the secret from the deployer's pod spec with `imagePullSecrets`. The
patch changes nothing else in the upstream Deployment. The pod keeps `runAsUser: 1000` and `runAsGroup: 0`, the image's
entrypoint, the image digest behind the tag, and `imagePullPolicy: Always`.

## Deploy with Kubeflow Pipelines

The upstream manifests set the cache deployer image in `manifests/kustomize/base/cache-deployer`. To use this image,
override it in your own kustomization. This example builds on the upstream `platform-agnostic` install for Kubeflow
Pipelines 2.18.0 and adds the pull secret from the previous section:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - github.com/kubeflow/pipelines/manifests/kustomize/env/platform-agnostic?ref=2.18.0
images:
  - name: ghcr.io/kubeflow/kfp-cache-deployer
    newName: dhi.io/kubeflow-pipelines-cache-deployer
    newTag: 2.18.0
patches:
  - target:
      kind: Deployment
      name: cache-deployer-deployment
    patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: cache-deployer-deployment
      spec:
        template:
          spec:
            imagePullSecrets:
              - name: dhi-pull-secret
```

Use the tag that matches your Kubeflow Pipelines release. Debian 13 tags have no distro suffix (`2.18.0`), and Alpine
tags end in `-alpine3.24` (`2.18.0-alpine3.24`).

Install the cluster-scoped resources, which include the deployer's ServiceAccount and ClusterRole, and then apply your
kustomization:

```bash
kubectl apply -k "github.com/kubeflow/pipelines/manifests/kustomize/cluster-scoped-resources?ref=2.18.0"
kubectl wait --for condition=established --timeout=60s crd/applications.app.k8s.io
kubectl apply -k .
```

The upstream Deployment runs the container with `runAsUser: 1000` and `runAsGroup: 0`, and it works unchanged with this
image. Check that the webhook was installed:

```bash
kubectl -n kubeflow logs deployment/cache-deployer-deployment | grep "Sleeping forever"
kubectl get mutatingwebhookconfiguration cache-webhook-kubeflow
```

### Run with a read-only root filesystem

Each run writes its working files to `/var/lib/kubeflow-pipelines-cache-deployer`, and the certificate script creates a
temporary directory under `/tmp`. To set `readOnlyRootFilesystem: true`, mount writable volumes at both paths. Add this
entry to the `patches:` list of the kustomization above, after the pull secret patch:

```yaml
  - target:
      kind: Deployment
      name: cache-deployer-deployment
    patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: cache-deployer-deployment
      spec:
        template:
          spec:
            containers:
              - name: main
                securityContext:
                  readOnlyRootFilesystem: true
                volumeMounts:
                  - name: state
                    mountPath: /var/lib/kubeflow-pipelines-cache-deployer
                  - name: tmp
                    mountPath: /tmp
            volumes:
              - name: state
                emptyDir: {}
              - name: tmp
                emptyDir: {}
```

Without the `/tmp` volume, the deployer exits with `mktemp: failed to create directory` and the pod restarts.

## Non-hardened images vs. Docker Hardened Images

- **User:** Runtime variants run as UID `65532`. The upstream image runs as root unless the manifest sets a user. The
  state directory and `HOME` (`/home/cache-deployer`) are owned by `65532:0` with mode `0770`, so the image's user and
  any UID that runs with `runAsGroup: 0`, like upstream's `1000`, can write to them.
- **kubectl:** `kubectl` is installed at `/usr/bin/kubectl`, with a `/usr/local/bin/kubectl` symlink at the upstream
  path. The deployer does not download a version-matched `kubectl` at startup. See
  [Check the bundled kubectl](#check-the-bundled-kubectl).
- **No curl or jq:** Upstream used them only to download `kubectl`. If you extend the scripts and need them, add them in
  a `dev` build stage.
- **Read-only scripts:** The scripts and webhook templates are owned by root and read-only, under
  `/usr/lib/kubeflow-pipelines-cache-deployer` and `/usr/share/kubeflow-pipelines-cache-deployer`. The upstream paths in
  `/kfp/cache/deployer` are symlinks to them. Upstream's directory was world-writable and the deployer wrote its working
  files next to the scripts. This image writes them to `KFP_CACHE_DEPLOYER_STATE_DIR` instead.
- **Shell:** The entrypoint is a shell script, so runtime variants include `/bin/sh` and `bash`, but no package manager.
  `/bin/sh` is `dash` on Debian 13 and BusyBox on Alpine.

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
