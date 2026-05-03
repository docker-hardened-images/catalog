## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### About this image

This Docker Hardened Azure Key Vault Controller image contains the `azure-keyvault-controller` binary from the
[akv2k8s](https://akv2k8s.io) project by Sparebanken Vest.

The controller watches `AzureKeyVaultSecret` custom resources in a Kubernetes cluster and synchronizes the referenced
secrets, certificates, and keys from Azure Key Vault into native Kubernetes `Secret` objects. Workloads consume the
synchronized values through standard mechanisms such as `envFrom`, `secretKeyRef`, or projected volumes — there are no
Azure credentials persisted in the cluster outside of the controller's own service principal or workload identity
binding.

The controller is one of three components in the akv2k8s project. The companion env-injector webhook
(`spvest/azure-keyvault-webhook`) and `vaultenv` init binary (`spvest/azure-keyvault-env`) are separate images and are
not included here. Use those images alongside the controller if you need direct env-var injection into pods without
persisting a Kubernetes Secret.

### Run the azure-keyvault-controller container

Azure Key Vault Controller is designed to run inside a Kubernetes cluster. It needs access to the Kubernetes API and to
Azure Key Vault, so it is not meaningfully run standalone with `docker run` against any real Key Vault. The image is
still useful to inspect locally before deploying.

To display help information:

```bash
docker run --rm dhi.io/azure-keyvault-controller:<tag> --help
```

### Deploy Azure Key Vault Controller in Kubernetes

The akv2k8s project publishes the controller as part of the `akv2k8s` Helm chart at `https://charts.spvapi.no`. The
recommended deployment method is to install that chart and override the controller image to point at the Docker Hardened
image. See the [upstream installation guide](https://akv2k8s.io/installation/) for full chart details.

1. Add the upstream chart repository:

   ```bash
   helm repo add spv-charts https://charts.spvapi.no
   helm repo update
   ```

1. Install the chart, overriding the image to point at the Docker Hardened image:

   ```bash
   helm install azure-keyvault-controller \
     spv-charts/akv2k8s \
     --namespace akv2k8s \
     --create-namespace \
     --set controller.image.repository=dhi.io/azure-keyvault-controller \
     --set controller.image.tag=<tag> \
     --set env_injector.enabled=false
   ```

   Replace `<tag>` with a tag from the **Tags** tab of this listing — for example a version-specific tag like
   `1.8.2-debian13` or a floating tag like `1`.

   The `akv2k8s` chart deploys both the controller and env-injector by default. The example above disables the
   env-injector because this image only replaces the controller component. Omit `--set env_injector.enabled=false` if
   you also want the chart to deploy the upstream env-injector images.

1. Verify the controller is running:

   ```bash
   kubectl -n akv2k8s get pod \
     -l app.kubernetes.io/component=azure-keyvault-controller-akv2k8s-controller
   ```

   You should see output similar to:

   ```
   NAME                                                         READY   STATUS    RESTARTS   AGE
   azure-keyvault-controller-akv2k8s-controller-76bd9c66c4-zk6vf 1/1     Running   0          30s
   ```

> **Note:** The dev variants of this image run as root and include a shell and package manager. If your deployment sets
> `runAsNonRoot: true` in the pod security context, dev variants will not start. Use a runtime variant in production and
> drop `runAsNonRoot` only when you specifically need a dev variant for debugging.

### Configure Azure authentication

The controller needs Azure credentials to read from Key Vault. The akv2k8s project supports several authentication modes
— service principal credentials in environment variables, AKS managed identity, AKS pod-managed identity, and Microsoft
Entra Workload Identity. Refer to the
[upstream authentication documentation](https://akv2k8s.io/security/authentication/) for the trade-offs and choose the
mode that fits your cluster.

For example, to use a service principal with environment-variable credentials, supply them through the chart's
`controller.env` values:

```bash
helm upgrade --install azure-keyvault-controller \
  spv-charts/akv2k8s \
  --namespace akv2k8s \
  --create-namespace \
  --set controller.image.repository=dhi.io/azure-keyvault-controller \
  --set controller.image.tag=<tag> \
  --set env_injector.enabled=false \
  --set global.keyVaultAuth=environment \
  --set controller.env.AZURE_TENANT_ID=<tenant-id> \
  --set controller.env.AZURE_CLIENT_ID=<client-id> \
  --set controller.env.AZURE_CLIENT_SECRET=<client-secret>
```

Production deployments should mount the client secret from a Kubernetes Secret rather than passing it on the command
line. See the upstream chart's `values.yaml` for the available knobs.

### Synchronize an Azure Key Vault secret

After the controller is running, define an `AzureKeyVaultSecret` resource that references a secret stored in Azure Key
Vault. The controller fetches the value and writes it as a native Kubernetes `Secret` that workloads can consume.

```yaml
apiVersion: spv.no/v2beta1
kind: AzureKeyVaultSecret
metadata:
  name: my-app-secret
  namespace: default
spec:
  vault:
    name: my-keyvault
    object:
      type: secret
      name: my-secret
  output:
    secret:
      name: my-app-secret
      dataKey: my-key
```

Apply the resource and inspect the resulting Secret:

```bash
kubectl apply -f azurekeyvaultsecret.yaml
kubectl get secret my-app-secret -o yaml
```

### Synchronize an Azure Key Vault certificate to a TLS Secret

The controller also handles certificates and writes them as Kubernetes TLS Secrets that ingress controllers and other
TLS consumers can use directly.

```yaml
apiVersion: spv.no/v2beta1
kind: AzureKeyVaultSecret
metadata:
  name: my-tls-cert
  namespace: default
spec:
  vault:
    name: my-keyvault
    object:
      type: certificate
      name: my-cert
  output:
    secret:
      name: my-tls-cert
      type: kubernetes.io/tls
```

### Monitor the controller

Follow the controller logs to observe synchronization activity and authentication events:

```bash
kubectl -n akv2k8s logs -f \
  -l app.kubernetes.io/component=azure-keyvault-controller-akv2k8s-controller \
  -c controller
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
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
