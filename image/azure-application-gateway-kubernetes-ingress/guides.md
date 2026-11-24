## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/azure-application-gateway-kubernetes-ingress:<tag>`
- Mirrored image: `<your-namespace>/dhi-azure-application-gateway-kubernetes-ingress:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

Azure Application Gateway Ingress Controller (AGIC) runs as a pod in an Azure Kubernetes Service (AKS) cluster. It
watches Ingress resources and the Services, endpoints and Secrets they reference, and configures an Azure Application
Gateway v2 through Azure Resource Manager. This image replaces
`mcr.microsoft.com/azure-application-gateway/kubernetes-ingress` on the 1.x line for installations with the upstream
Helm chart. The AGIC add-on for AKS is managed by Microsoft and deploys its own image. The upstream project documents
the prerequisites, Azure permissions, annotations and chart at
https://azure.github.io/application-gateway-kubernetes-ingress/ and
https://learn.microsoft.com/azure/application-gateway/ingress-controller-overview.

The runtime tags are `dhi.io/azure-application-gateway-kubernetes-ingress:1` (Debian 13) and
`dhi.io/azure-application-gateway-kubernetes-ingress:1-alpine3.24` (Alpine 3.24). Version tags, such as
`<version>-debian13`, pin the AGIC release; replace `<version>` with a release number, such as the one the chart
installs.

## Start an AGIC image

The image has no entrypoint and the default command is `/appgw-ingress`, the same as upstream. Arguments you pass to
`docker run` replace the command, so start them with the binary path. Runtime tags run as UID 65532 and contain no
shell.

### Basic usage

```bash
docker run --rm dhi.io/azure-application-gateway-kubernetes-ingress:<tag> /appgw-ingress --version
```

Use `/appgw-ingress --help` to list the command-line flags. The controller needs a Kubernetes API server and access to
an Application Gateway. Started without them, as in a plain `docker run`, it exits with
`Error creating in-cluster client configuration`.

### Install with the upstream Helm chart

Follow the upstream
[installation guide](https://github.com/Azure/application-gateway-kubernetes-ingress/blob/%3Cversion%3E/docs/setup/install.md)
to create the Application Gateway, the managed identity, its role assignments and the workload identity federation for
the `ingress-azure` service account. Then install the chart, using the same release for `<version>` in the chart version
and the image tag, and point its image at this image:

```bash
helm install ingress-azure \
  oci://mcr.microsoft.com/azure-application-gateway/charts/ingress-azure \
  --version <version> \
  --set image.repository=dhi.io/azure-application-gateway-kubernetes-ingress \
  --set image.tag=<version>-debian13 \
  --set image.pullSecrets=dhi-pull-secret \
  --set appgw.applicationGatewayID=$APPGW_ID \
  --set armAuth.type=workloadIdentity \
  --set armAuth.identityClientID=$IDENTITY_CLIENT_ID \
  --set rbac.enabled=true
```

Create the `dhi-pull-secret` image pull secret for `dhi.io` in the release namespace first. The chart reads
`image.pullSecrets` as a single secret name, not a list.

By default the chart sets the pod `securityContext` to `runAsUser: 0`, which overrides the image user. A chart install
therefore runs the controller as root, as it does with the upstream image, and needs no other changes.

### Uninstall with the chart

`helm uninstall` runs a pre-delete Job from the chart. The Job starts this image with
`/appgw-ingress --cleanup-oec app.kubernetes.io/managed-by=ingress-appgw-helm`, which deletes the
`OverlayExtensionConfig` resources the controller created, and logs a warning and skips the cleanup when that CRD is not
installed. The Job sets no `runAsUser`, so it runs as UID 65532.

### Run as the nonroot user

To run the controller as the image's nonroot user, override the pod security context in a values file and pass it to the
`helm install` command above with `-f nonroot-values.yaml`:

```yaml
kubernetes:
  securityContext:
    runAsUser: 65532
    runAsGroup: 65532
    runAsNonRoot: true
```

Check what the controller reads as UID 65532:

- The chart mounts the node's `/etc/kubernetes/` directory at `/etc/appgw/` and sets `AZURE_CLOUD_PROVIDER_LOCATION` to
  `/etc/appgw/azure.json`. If you rely on that file for credentials or for the gateway's subscription and resource
  group, it must be readable by UID 65532. With `armAuth.type=workloadIdentity` and `appgw.applicationGatewayID`, as in
  the example above, the controller does not need the file. When it cannot read it, it logs
  `Unable to load cloud provider config` and continues.
- AGIC writes the certificate and key of each Ingress TLS Secret to temporary files in `/tmp` before converting them.
  `/tmp` is writable in the image. If you set `readOnlyRootFilesystem: true` in `kubernetes.containerSecurityContext`,
  mount an `emptyDir` at `/tmp` with `kubernetes.volumes.extraVolumes` and `kubernetes.volumes.extraVolumeMounts`, as
  the commented example in the chart's
  [values.yaml](https://github.com/Azure/application-gateway-kubernetes-ingress/blob/%3Cversion%3E/helm/ingress-azure/values.yaml)
  shows.

### Expose a Service through Application Gateway

The chart creates the `azure-application-gateway` IngressClass. An Ingress that uses it makes AGIC add a backend pool
with the Service's pod IPs, a listener, a routing rule and a health probe to the gateway:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: default
spec:
  ingressClassName: azure-application-gateway
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

The `appgw.ingress.kubernetes.io/*` annotations that tune probes, timeouts, redirects and TLS are listed in the upstream
[annotations reference](https://github.com/Azure/application-gateway-kubernetes-ingress/blob/%3Cversion%3E/docs/annotations.md).

### Health and metrics

The controller serves `/health/ready`, `/health/alive` and Prometheus metrics at `/metrics` on port 8123. The chart sets
the port with `kubernetes.httpServicePort`, uses the first two paths for the readiness and liveness probes, and adds
`prometheus.io/scrape` and `prometheus.io/port` annotations to the pod.

## FIPS variants and Ingress TLS Secrets

The FIPS tags, such as `1-fips` and `1-alpine3.24-fips`, build the controller with the Go FIPS 140-3 cryptographic
module, which covers its TLS connections to Azure Resource Manager, Microsoft Entra ID and the Kubernetes API server.
The `openssl` command in these tags uses the OpenSSL FIPS provider.

On the FIPS tags, AGIC can't use Kubernetes TLS Secrets referenced in an Ingress `spec.tls`. AGIC converts each Secret
to PKCS#12 with `openssl pkcs12 -export`, and the PKCS#12 integrity MAC it requests depends on a key derivation function
(PKCS12KDF) that is not FIPS-approved. OpenSSL fails with `Error creating PKCS12 MAC; no PKCS12KDF support?`, AGIC logs
`unable to export using openssl`, and the certificate is not uploaded to the gateway. Ingresses without TLS are not
affected.

To terminate TLS on a FIPS tag, add the certificate to the Application Gateway yourself, either as a file or from Azure
Key Vault, and reference it by name with the `appgw.ingress.kubernetes.io/appgw-ssl-certificate` annotation. Leave out
`spec.tls`. The upstream
[certificate guide](https://github.com/Azure/application-gateway-kubernetes-ingress/blob/%3Cversion%3E/docs/features/appgw-ssl-certificate.md)
shows how to add both kinds of certificate.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web
  namespace: default
  annotations:
    appgw.ingress.kubernetes.io/appgw-ssl-certificate: mysslcert
spec:
  ingressClassName: azure-application-gateway
  rules:
    - host: www.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 80
```

## Non-hardened images vs. Docker Hardened Images

- The upstream image sets no user and runs as root. This image runs as UID 65532. The upstream chart sets `runAsUser: 0`
  by default, so chart installs run as root with either image. To run as UID 65532, see
  [Run as the nonroot user](#run-as-the-nonroot-user).
- The upstream image is built on Azure Linux with the binary at `/appgw-ingress`. This image is built on Debian 13 or
  Alpine 3.24, installs the binary at `/usr/bin/appgw-ingress`, and keeps `/appgw-ingress` as a symlink to it. The
  default command is the same, so `command:` and `args:` overrides work unchanged. To extract the binary with
  `docker cp`, copy `/usr/bin/appgw-ingress` or pass `-L`. Without `-L`, `docker cp` copies the symlink.
- On the FIPS tags, Ingress `spec.tls` Secrets are not converted. See
  [FIPS variants and Ingress TLS Secrets](#fips-variants-and-ingress-tls-secrets).

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
