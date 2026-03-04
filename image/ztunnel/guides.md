## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/ztunnel:<tag>`
- Mirrored image: `<your-namespace>/dhi-ztunnel:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this ztunnel image

This Docker Hardened Image includes:

- `ztunnel` binary — Rust-based per-node L4 proxy for Istio ambient mesh
- Standard TLS certificates for secure communication
- Prometheus metrics endpoint on port 15020 (`/metrics` and `/stats/prometheus`)
- Health check endpoint on port 15021 (`/healthz/ready`)
- CIS benchmark compliance (runtime), FIPS 140 + STIG + CIS compliance (FIPS variant, requires DHI Enterprise
  subscription)

## Start a ztunnel instance

Ztunnel is a per-node DaemonSet proxy for Istio ambient mesh. It is not designed to run as a standalone container. It
requires the Istio control plane (Istiod) and Istio CNI to function. You must install these components before installing
ztunnel.

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

Log in to the DHI Helm registry:

```console
$ helm registry login dhi.io
```

Create a Kubernetes namespace and secret for pulling DHI images:

```console
$ kubectl create namespace istio-system
$ kubectl create secret docker-registry dhi-pull-secret \
    --docker-server=dhi.io \
    --docker-username=<Docker username> \
    --docker-password=<Docker token> \
    --docker-email=<Docker email> \
    -n istio-system
```

Install the Istio control plane prerequisites:

```console
$ helm install istio-base oci://dhi.io/istio-base-chart --version <version> \
    -n istio-system --wait
$ helm install istiod oci://dhi.io/istio-discovery-chart --version <version> \
    -n istio-system \
    --set "global.imagePullSecrets[0]=dhi-pull-secret" \
    --set profile=ambient --wait
```

Install the Istio CNI using the upstream Helm chart with the DHI image override:

```console
$ helm repo add istio https://istio-release.storage.googleapis.com/charts
$ helm install istio-cni istio/cni --version <version> \
    -n istio-system \
    --set hub=dhi.io \
    --set image=istio-install-cni \
    --set tag=<tag> \
    --set "global.imagePullSecrets[0]=dhi-pull-secret" \
    --set ambient.enabled=true --wait
```

> **Note:** There is no DHI Helm chart for Istio CNI. The command above uses the upstream `istio/cni` chart with the DHI
> image override (`dhi.io/istio-install-cni`).

Install ztunnel using the DHI Helm chart. Replace `<version>` with the chart version:

```console
$ helm install ztunnel oci://dhi.io/ztunnel-chart --version <version> \
    --namespace istio-system \
    --set "imagePullSecrets[0]=dhi-pull-secret" \
    --wait
```

Verify the ztunnel DaemonSet is running:

```console
$ kubectl get pods -n istio-system -l app=ztunnel
```

## Common ztunnel use cases

### Ambient mesh L4 proxy for zero-trust service-to-service communication

Ztunnel is the foundational data plane component of Istio's ambient mesh mode. It runs as a DaemonSet on every node and
automatically intercepts all traffic for enrolled workloads, encrypting it with mutual TLS (mTLS) without requiring
sidecar injection or application code changes.

After completing the installation steps in [Start a ztunnel instance](#start-a-ztunnel-instance), enroll a namespace in
the ambient mesh:

```console
$ kubectl label namespace default istio.io/dataplane-mode=ambient
```

Deploy sample workloads to verify traffic flows through ztunnel:

```console
$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/bookinfo/platform/kube/bookinfo.yaml
$ kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.28/samples/sleep/sleep.yaml
```

Test encrypted service-to-service communication:

```console
$ kubectl exec deploy/sleep -- curl -s -o /dev/null -w "%{http_code}" http://productpage:9080/
```

Expected output: `200`

Verify mTLS is active by checking ztunnel logs for HBONE tunnel connections:

```console
$ kubectl logs -n istio-system -l app=ztunnel --tail=20
```

### FIPS-compliant service mesh deployments

For organizations that require Federal Information Processing Standards (FIPS) compliance, the DHI ztunnel FIPS variant
ensures all cryptographic operations use a FIPS 140-2 validated OpenSSL module. In FIPS mode, ztunnel is compiled with
`--no-default-features --features tls-openssl` instead of the default Rustls TLS backend.

> **Note:** FIPS variants require a DHI Enterprise subscription. Contact Docker for access.

Install ztunnel with the FIPS variant using the DHI Helm chart. Use a FIPS-tagged image by setting the appropriate tag
value:

```console
$ helm install ztunnel oci://dhi.io/ztunnel-chart --version <version> \
    -n istio-system \
    --set "imagePullSecrets[0]=dhi-pull-secret" \
    --set tag=<tag>-fips \
    --wait
```

Verify FIPS mode is active by checking the container environment variables (the runtime image does not include a shell
or `env` command):

```console
$ kubectl get pod -n istio-system \
    $(kubectl get pods -n istio-system -l app=ztunnel -o jsonpath='{.items[0].metadata.name}') \
    -o jsonpath='{.spec.containers[0].env}' | grep -i fips
```

Alternatively, use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to inspect the running container
directly.

### Deploy ztunnel in Kubernetes

Ztunnel is designed exclusively for Kubernetes and deploys as a DaemonSet via Helm. Follow the steps in
[Start a ztunnel instance](#start-a-ztunnel-instance) to install the full stack.

Verify the DaemonSet is running on all nodes:

```console
$ kubectl get pods -n istio-system -l app=ztunnel -o wide
```

Enroll a namespace in ambient mesh:

```console
$ kubectl label namespace default istio.io/dataplane-mode=ambient
```

Remove a namespace from the mesh (no pod restarts required):

```console
$ kubectl label namespace default istio.io/dataplane-mode-
```

> **Note:** Ztunnel runs as user `nonroot` by default. The DHI Helm chart manages the DaemonSet configuration including
> security contexts and required capabilities.

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Feature             | DOI (`istio/ztunnel`)        | DHI (`dhi.io/ztunnel`)              |
| ------------------- | ---------------------------- | ----------------------------------- |
| User                | (empty — defaults to root)   | `nonroot`                           |
| Shell               | Yes                          | No (runtime), Yes (dev)             |
| Package manager     | No                           | No (runtime), Yes (dev)             |
| Entrypoint          | `["/usr/local/bin/ztunnel"]` | `["ztunnel"]`                       |
| Image size          | 255MB                        | 58.5MB                              |
| Zero CVE commitment | No                           | Yes                                 |
| FIPS variant        | No                           | Yes (FIPS + STIG + CIS)             |
| Base OS             | Ubuntu-based                 | Docker Hardened Images (Debian 13)  |
| Compliance labels   | None                         | CIS (runtime), FIPS+STIG+CIS (fips) |
| Architectures       | `linux/amd64`, `linux/arm64` | `linux/amd64`, `linux/arm64`        |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

### Runtime variants

Runtime variants are the default production images. They run as the `nonroot` user, do not include a shell or package
manager, and are CIS benchmark compliant. These are the recommended variants for production ambient mesh deployments.

### Dev variants

Dev variants include `-dev` in the tag name. They run as `root` and include a shell and package manager. Use dev
variants for debugging, troubleshooting, and development environments. Dev variants are CIS compliant.

### FIPS variants

FIPS variants include `-fips` in the tag name. They are built with FIPS 140-2 validated OpenSSL instead of the default
Rustls TLS backend. All TLS operations use the OpenSSL FIPS module
([Certificate #4282](https://csrc.nist.gov/projects/cryptographic-module-validation-program/certificate/4282)). FIPS
variants run as the `nonroot` user and are CIS, FIPS, and STIG compliant. FIPS configuration is automatically applied at
runtime.

> **Note:** FIPS and STIG variants require a DHI Enterprise subscription. Contact Docker for access.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                                                    |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                                       |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

## Troubleshoot migration

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
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
