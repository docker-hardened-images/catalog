## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What’s Included in the cert-manager-acmesolver Image

The **Docker Hardened cert-manager-acmesolver** image provides the **ACME solver component** of
[cert-manager](https://cert-manager.io) as a single, security-hardened package. This image is designed to perform ACME
challenge validation as part of the certificate issuance process in Kubernetes.

It includes:

- `cert-manager-acmesolver`: The primary binary that handles ACME challenge solving.
- TLS certificate management capabilities for Kubernetes clusters.
- ACME protocol support for automatic certificate provisioning from providers like Let’s Encrypt.
- Automated certificate renewal and lifecycle management.

## Start a cert-manager-acmesolver Image

Run the following command, replacing `<tag>` with the desired image variant:

> **Note:** The cert-manager-acmesolver image is primarily designed to run inside a Kubernetes cluster as part of a full
> cert-manager deployment. The standalone Docker command below simply displays configuration options.

```bash
docker run --rm -it dhi.io/cert-manager-acmesolver:<tag> --help
```

## Common cert-manager-acmesolver Use Cases

### Deploy cert-manager-acmesolver in Kubernetes

Follow the [DHI authentication instructions for Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

`acmesolver` is typically deployed as part of the full cert-manager stack. Here’s an example `Deployment` configuration:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cert-manager-acmesolver
  namespace: cert-manager
spec:
  template:
    spec:
      containers:
      - name: cert-manager-acmesolver
        image: dhi.io/cert-manager-acmesolver:<tag>
        args:
        - --domain=example.com # the domain name to verify
        - --token=my_token     # the challenge token to verify against
        - --key=my_key         # the challenge key to respond with
      imagePullSecrets:
      - name: <secret name>
```

### Integrate with Multiple Certificate Authorities

cert-manager-acmesolver supports multiple issuer types, including **ACME**, **CA**, **Vault**, **Venafi**, and
**self-signed**.

Example `ClusterIssuer` for Let’s Encrypt:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

**Note:** cert-manager consists of multiple components (controller, acmesolver, cainjector, webhook) that work together.
Each component may be available as a separate Docker Hardened Image for deployment flexibility.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or Kubernetes manifests. At
minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This and a few other
common changes are listed in the following table of migration notes:

| Item               | Migration note                                                                                                                                                                     |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile or Kubernetes manifests with a Docker Hardened Image.                                                                                  |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                          |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                         |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                             |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                 |
| Ports              | Non-dev hardened images run as a nonroot user by default. cert-manager-acmesolver typically uses port 8089 for metrics, which works without issues.                                |
| Entry point        | Docker Hardened Images may have different entry points than standard cert-manager images. Inspect entry points for Docker Hardened Images and update your deployment if necessary. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.        |
| Kubernetes RBAC    | Ensure RBAC permissions are correctly configured as cert-manager-acmesolver requires specific permissions to manage certificates and secrets.                                      |

The following steps outline the general migration process.

1. **Find hardened images for your app.** The cert-manager-acmesolver hardened image may have several variants. Inspect
   the image tags and find the image variant that meets your needs. Remember that cert-manager requires multiple
   components to function properly.
1. **Update the image references in your Kubernetes manifests.** Update the image references in your cert-manager
   deployment manifests to use the hardened images. If using Helm, update your values file accordingly.
1. **For custom deployments, update the runtime image in your Dockerfile.** If you're building custom images based on
   cert-manager, ensure that your final image uses the hardened cert-manager-acmesolver as the base.
1. **Verify component compatibility** Ensure all cert-manager components (controller, webhook, cainjector, acmesolver)
   are using compatible versions. The acmesolver works in conjunction with these other components.
1. **Test certificate issuance** After migration, test that certificate issuance and renewal workflows continue to
   function correctly with the hardened images.

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than standard cert-manager images. Use `docker inspect` to
inspect entry points for Docker Hardened Images and update your Kubernetes deployment if necessary.

### cert-manager-Specific Issues

- **Missing components:** Ensure all required cert-manager components (acmesolver, webhook, cainjector, controller) are
  deployed and version-compatible.
- **Certificate issuance failures:** Review acmesolver logs for ACME challenge or issuer configuration errors.
- **Webhook connectivity:** Confirm network policies permit communication between acmesolver and webhook pods.
- **Leader election problems:** In multi-replica setups, verify that leader election operates correctly to avoid
  duplicate operations.
