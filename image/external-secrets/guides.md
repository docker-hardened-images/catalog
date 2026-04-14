## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/external-secrets:<tag>`
- Mirrored image: `<your-namespace>/dhi-external-secrets:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this External Secrets Operator image

This Docker Hardened External Secrets Operator image includes:

- External Secrets Operator controller for syncing secrets from external providers into Kubernetes Secrets
- Webhook server for validating and converting ExternalSecret custom resources
- Certificate controller for managing internal TLS certificates
- Support for major secret providers including AWS Secrets Manager, HashiCorp Vault, Google Secret Manager, Azure Key
  Vault, IBM Cloud Secrets Manager, CyberArk, and more

## Start an External Secrets Operator instance

The External Secrets Operator is a Kubernetes operator that syncs secrets from external providers into Kubernetes
Secrets. It cannot run as a standalone container outside of Kubernetes as it requires access to the Kubernetes API and
ExternalSecret custom resources.

### View available flags

Run the following command to view the External Secrets Operator flags. Replace `<tag>` with the image variant you want
to run.

```
$ docker run --rm dhi.io/external-secrets:<tag> --help
```

The operator exposes three subcommands, each corresponding to a component:

- `external-secrets` (default) — the main controller
- `external-secrets webhook` — the webhook server (port 10250)
- `external-secrets certcontroller` — the certificate controller

### Deploy to Kubernetes using Helm

First follow the
[authentication instructions for DHI in Kubernetes](https://docs.docker.com/dhi/how-to/k8s/#authentication).

Add the official External Secrets Operator Helm chart repo:

```
$ helm repo add external-secrets https://charts.external-secrets.io
```

The External Secrets Operator deploys three components (controller, webhook, and cert-controller), so all three image
references must point to the DHI image:

```
$ helm upgrade --install external-secrets external-secrets/external-secrets \
   -n external-secrets --create-namespace \
   --set image.repository=dhi.io/external-secrets \
   --set webhook.image.repository=dhi.io/external-secrets \
   --set certController.image.repository=dhi.io/external-secrets \
   --set "imagePullSecrets[0].name=registry-credentials"
```

Verify the deployment:

```
$ kubectl get pods -n external-secrets
```

You should see three pods running: the controller, the webhook, and the cert-controller.

### Upgrade an existing Helm deployment to DHI

If you already have the External Secrets Operator deployed with the upstream image, update your Helm values to use the
DHI image. All three components must be updated:

```
$ helm upgrade external-secrets external-secrets/external-secrets \
   -n external-secrets \
   --set image.repository=dhi.io/external-secrets \
   --set webhook.image.repository=dhi.io/external-secrets \
   --set certController.image.repository=dhi.io/external-secrets \
   --set "imagePullSecrets[0].name=registry-credentials"
```

Verify all three components are using the DHI image:

```
$ kubectl get deployment -n external-secrets -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.template.spec.containers[0].image}{"\n"}{end}'
```

## Common External Secrets Operator use cases

### Sync secrets from AWS Secrets Manager

Create a Kubernetes Secret containing your AWS credentials, then create a SecretStore and ExternalSecret to sync secrets
into your cluster.

```
$ kubectl create secret generic awssm-secret \
   -n external-secrets \
   --from-literal=access-key=<YOUR_ACCESS_KEY_ID> \
   --from-literal=secret-access-key=<YOUR_SECRET_ACCESS_KEY>
```

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: aws-secretstore
  namespace: external-secrets
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1 # Or the regions where your secrets are
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: awssm-secret
            key: access-key
          secretAccessKeySecretRef:
            name: awssm-secret
            key: secret-access-key
```

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: my-app-secret
  namespace: external-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretstore
    kind: SecretStore
  target:
    name: my-app-k8s-secret
    creationPolicy: Owner
  data:
    - secretKey: password
      remoteRef:
        key: my-app/password
```

Verify the secret was synced:

```
$ kubectl get externalsecret my-app-secret -n external-secrets
$ kubectl get secret my-app-k8s-secret -n external-secrets
```

### Use a ClusterSecretStore for cluster-wide access

A ClusterSecretStore is a cluster-scoped resource that can be referenced from any namespace. This is useful when you
want to share a single secret provider configuration across multiple teams:

```yaml
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: global-aws-store
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: awssm-secret
            namespace: external-secrets
            key: access-key
          secretAccessKeySecretRef:
            name: awssm-secret
            namespace: external-secrets
            key: secret-access-key
```

Then reference it from any namespace:

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: my-secret
  namespace: my-app
spec:
  refreshInterval: 30m
  secretStoreRef:
    name: global-aws-store
    kind: ClusterSecretStore
  target:
    name: app-credentials
  data:
    - secretKey: db-password
      remoteRef:
        key: production/database/password
```

### Sync secrets from HashiCorp Vault

Create a SecretStore pointing to a Vault instance and an ExternalSecret to sync a secret from it:

```yaml
apiVersion: external-secrets.io/v1
kind: SecretStore
metadata:
  name: vault-store
  namespace: default
spec:
  provider:
    vault:
      server: "https://vault.example.com"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: vault-token
          key: token
```

```yaml
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: vault-secret
  namespace: default
spec:
  refreshInterval: 15m
  secretStoreRef:
    name: vault-store
    kind: SecretStore
  target:
    name: my-vault-secret
  data:
    - secretKey: api-key
      remoteRef:
        key: apps/my-app
        property: api-key
```

## Official Docker image (DOI) vs Docker Hardened Image (DHI)

| Feature         | DOI (`ghcr.io/external-secrets/external-secrets`) | DHI (`dhi.io/external-secrets`)    |
| :-------------- | :------------------------------------------------ | :--------------------------------- |
| User            | nonroot (65532)                                   | nonroot (65532)                    |
| Shell           | Yes                                               | No (runtime) / Yes (dev)           |
| Package manager | Yes                                               | No (runtime) / Yes (dev)           |
| FIPS variant    | No                                                | Yes                                |
| STIG compliance | No                                                | Yes (100%)                         |
| Base OS         | Distroless                                        | Docker Hardened Images (Debian 13) |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as a nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a multi-stage
Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. For example, usage of MD5 fails in FIPS variants.

The External Secrets Operator Docker Hardened Image is available in all variant types: runtime, dev, FIPS, and FIPS-dev.
To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

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

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
