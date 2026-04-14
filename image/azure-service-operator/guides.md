## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Install Azure Service Operator using Helm

The recommended way to install Azure Service Operator is using the official Helm chart. Replace `<tag>` with the image
variant you want to run.

```bash
# Add the Azure Service Operator Helm repository
helm repo add aso2 https://raw.githubusercontent.com/Azure/azure-service-operator/main/v2/charts
helm repo update

# Install with basic configuration
helm install aso2 aso2/azure-service-operator \
  --create-namespace \
  --namespace azureserviceoperator-system \
  --set image.repository=dhi.io/azure-service-operator:<tag> \
  --set azureTenantID="your-tenant-id" \
  --set azureSubscriptionID="your-subscription-id" \
  --set azureClientID="your-client-id" \
  --set azureClientSecret="your-client-secret"
```

### Run Azure Service Operator directly

For testing or development purposes, you can run the operator directly:

```bash
# Run with required environment variables
docker run --rm -e AZURE_TENANT_ID="your-tenant-id" \
  -e AZURE_SUBSCRIPTION_ID="your-subscription-id" \
  -e AZURE_CLIENT_ID="your-client-id" \
  -e AZURE_CLIENT_SECRET="your-client-secret" \
  dhi.io/azure-service-operator:<tag>
```

> [!NOTE] This direct approach is for testing only. Production deployments should use the Helm chart for proper RBAC,
> webhooks, and CRD management.

## Authentication methods

Azure Service Operator supports multiple authentication methods to connect to Azure:

### Service Principal (Client Secret)

The most common authentication method using a service principal:

```yaml
# values.yaml for Helm installation
azureTenantID: "your-tenant-id"
azureSubscriptionID: "your-subscription-id"
azureClientID: "your-service-principal-client-id"
azureClientSecret: "your-service-principal-secret"
```

### Workload Identity (Recommended for AKS)

For AKS clusters, use Azure Workload Identity for enhanced security:

```yaml
# values.yaml for Helm installation
azureTenantID: "your-tenant-id"
azureSubscriptionID: "your-subscription-id"
azureClientID: "your-managed-identity-client-id"
useWorkloadIdentityAuth: true

# Pod identity configuration
podLabels:
  azure.workload.identity/use: "true"
```

### Client Certificate

Authenticate using a client certificate:

```yaml
# values.yaml for Helm installation
azureTenantID: "your-tenant-id"
azureSubscriptionID: "your-subscription-id"
azureClientID: "your-service-principal-client-id"
azureClientCertificate: |
  -----BEGIN CERTIFICATE-----
  [certificate content]
  -----END CERTIFICATE-----
azureClientCertificatePassword: "certificate-password" # Optional
```

## Common use cases

Azure Service Operator enables you to manage Azure resources directly from Kubernetes manifests.

### Provision an Azure Storage Account

```yaml
apiVersion: storage.azure.com/v1api20210401
kind: StorageAccount
metadata:
  name: mystorageaccount
  namespace: default
spec:
  location: eastus
  resourceGroupRef:
    name: myresourcegroup
  kind: StorageV2
  sku:
    name: Standard_LRS
```

### Create an Azure Database for PostgreSQL

```yaml
apiVersion: dbforpostgresql.azure.com/v1api20210601
kind: FlexibleServer
metadata:
  name: mypostgresql
  namespace: default
spec:
  location: eastus
  resourceGroupRef:
    name: myresourcegroup
  administratorLogin: myadmin
  administratorLoginPassword:
    name: postgresql-secret
    key: password
  storage:
    storageSizeGB: 32
  sku:
    name: Standard_B1ms
    tier: Burstable
  version: "13"
```

### Multi-tenant configuration

For managing resources across multiple tenants:

```yaml
# values.yaml for Helm installation
azureTenantID: "primary-tenant-id"
azureAdditionalTenants: "tenant-id-1,tenant-id-2,tenant-id-3"
multitenant:
  enable: true
```

## Configuration options

### Namespace targeting

Control which namespaces the operator monitors:

```yaml
# values.yaml - Monitor specific namespaces only
azureTargetNamespaces: ["production", "staging"]

# Or monitor all namespaces (default)
azureTargetNamespaces: []
```

### Sync period configuration

```yaml
# values.yaml - Set how often resources are re-synced with Azure
azureSyncPeriod: "1h"  # Options: "1h", "30m", "never"
```

### CRD management

```yaml
# values.yaml - Control which CRDs to install
installCRDs: true
crdPattern: "resources.azure.com/*;compute.azure.com/*;storage.azure.com/*"
```

### Metrics and monitoring

```yaml
# values.yaml - Enable metrics endpoint
metrics:
  enable: true
  secure: true  # Serve over HTTPS
  port: 8443
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

## Migrate to a Docker Hardened Image

To migrate your Azure Service Operator deployment to a Docker Hardened Image, you must update your Helm values or
Kubernetes manifests. At minimum, you must update the container image reference to use a Docker Hardened Image. This and
a few other common changes are listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your container image references in your Helm values or Kubernetes manifests with a Docker Hardened Image.                                                                                                                                                                                                            |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Nonroot user       | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. **Update your Helm values or Kubernetes manifests**

   Replace the existing image reference in your Helm values file:

   ```yaml
   # Before
   image:
     repository: mcr.microsoft.com/k8s/azureserviceoperator:v2.15.0

   # After
   image:
     repository: dhi.io/azure-service-operator:<tag>
   ```

1. **Verify authentication configuration**

   Ensure your authentication method is properly configured and the operator can connect to Azure.

1. **Test with a subset of resources**

   Start by deploying the operator in a test namespace and verify it can manage a simple Azure resource like a Resource
   Group.

1. **Monitor webhook and CRD functionality**

   Verify that webhooks are working correctly and CRDs are installed as expected.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Authentication failures

If the operator fails to authenticate with Azure:

1. **Verify credentials**: Ensure all required authentication parameters are correctly configured
1. **Check service principal permissions**: Verify the service principal has appropriate RBAC roles in your Azure
   subscription
1. **Validate tenant and subscription IDs**: Confirm the tenant and subscription IDs are correct
1. **Test workload identity setup**: For workload identity, verify the federated identity credential is properly
   configured

### CRD installation issues

If CRDs are not installing correctly:

1. **Check CRD patterns**: Verify your `crdPattern` setting matches the resources you want to manage
1. **Verify cluster permissions**: Ensure the operator has cluster-admin permissions to install CRDs
1. **Review operator logs**: Check the operator logs for specific CRD installation errors

### Resource reconciliation problems

If Azure resources are not being created or updated:

1. **Check resource status**: Use `kubectl describe` to check the status conditions of your Custom Resources
1. **Review Azure permissions**: Verify the authenticated identity has permissions to create the specific Azure
   resources
1. **Validate resource group references**: Ensure referenced resource groups exist and are accessible
1. **Monitor sync periods**: Check if resources are being reconciled according to your `azureSyncPeriod` setting

### Webhook configuration issues

If validation webhooks are not working:

1. **Verify webhook certificates**: Ensure webhook certificates are properly configured and not expired
1. **Check network policies**: If using network policies, ensure webhook traffic is allowed
1. **Validate webhook service**: Confirm the webhook service is accessible from the Kubernetes API server

### Performance and scaling

For performance optimization:

1. **Adjust concurrent reconciles**: Use `MAX_CONCURRENT_RECONCILES` environment variable to control parallelism
1. **Configure rate limiting**: Set appropriate `RATE_LIMIT_QPS` and `RATE_LIMIT_BUCKET_SIZE` values
1. **Optimize sync periods**: Use longer sync periods for stable environments to reduce Azure API calls
1. **Scale replicas**: Increase replica count for high-availability deployments

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than upstream images. The Azure Service Operator DHI uses
`/aso-controller` as the entry point. If you're customizing the container command or args, ensure they're compatible
with this entry point.
