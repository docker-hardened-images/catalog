## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/cert-manager-google-cas-issuer:<tag>`
- Mirrored image: `<your-namespace>/dhi-cert-manager-google-cas-issuer:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Google CAS Issuer is a cert-manager external issuer. It runs as a controller in the cluster and signs cert-manager
`CertificateRequest` resources with a Google Cloud Certificate Authority Service (CAS) pool. This image replaces
`quay.io/jetstack/cert-manager-google-cas-issuer` on the 0.x line. Issuer configuration and the Google Cloud setup (CA
pool, service account, IAM roles) are documented at https://github.com/cert-manager/google-cas-issuer.

The Debian 13 runtime tag is `dhi.io/cert-manager-google-cas-issuer:0`. The Alpine 3.24 runtime tag is
`dhi.io/cert-manager-google-cas-issuer:0-alpine3.24`.

## Start a Google CAS Issuer image

The entrypoint is `/usr/local/bin/google-cas-issuer`, and the image sets no command. Runtime tags run as user 65532 and
contain no shell.

### Basic usage

```bash
docker run --rm dhi.io/cert-manager-google-cas-issuer:0 --help
```

Outside a cluster, point the `KUBECONFIG` environment variable at a kubeconfig file. The binary has no `--kubeconfig`
flag.

### Install with the upstream Helm chart

The issuer needs cert-manager, so install cert-manager first. Then install the upstream chart and point it at this
image. Pass the tag with `--set-string`, because the chart schema requires `image.tag` to be a string. Create the
`dhi-pull-secret` image pull secret for `dhi.io` in the target namespace first.

```bash
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager-google-cas-issuer jetstack/cert-manager-google-cas-issuer \
  --namespace cert-manager \
  --set image.repository=dhi.io/cert-manager-google-cas-issuer \
  --set-string image.tag=0 \
  --set imagePullSecrets[0].name=dhi-pull-secret
```

The chart runs the pod with `runAsNonRoot: true` and a read-only root filesystem. Use a runtime tag, such as `0` or
`0-alpine3.24`. Dev tags run as root and the pod is rejected.

### Configure an issuer

A `GoogleCASIssuer` names a CAS pool. With `credentials`, the controller reads a service account key from a Secret in
the issuer's namespace. Without `credentials`, it uses the ambient Google credentials of the pod, for example Workload
Identity on GKE.

```yaml
apiVersion: cas-issuer.jetstack.io/v1beta1
kind: GoogleCASIssuer
metadata:
  name: googlecasissuer-sample
  namespace: default
spec:
  project: my-project
  location: europe-west1
  caPoolId: my-pool
  credentials:
    name: googlesa
    key: key.json
```

`kubectl get googlecasissuers` shows `READY` as `True` once the controller can build a CAS client from the credentials.
A `Certificate` then uses the issuer with `issuerRef.group: cas-issuer.jetstack.io` and
`issuerRef.kind: GoogleCASIssuer`.

### Metrics

The controller serves Prometheus metrics on `--metrics-addr`. The default is `:8080` and the chart sets `:9402`. The
chart creates no Service, so forward a local port to the pod in one terminal:

```bash
kubectl -n cert-manager port-forward deploy/cert-manager-google-cas-issuer 9402
```

Then read the metrics from another terminal:

```bash
curl -s http://localhost:9402/metrics | grep controller_runtime_reconcile_total
```

## Non-hardened images vs. Docker Hardened Images

- The images are built for `linux/amd64` and `linux/arm64`. The upstream image also publishes `linux/arm/v7` and
  `linux/ppc64le`.
- The Debian tags install Debian's `tzdata` without `tzdata-legacy`, so legacy zone names such as `US/Eastern` are
  missing and `TZ` set to one falls back to UTC. Use a canonical name such as `America/New_York`, or an Alpine tag.

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
