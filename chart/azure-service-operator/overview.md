## About this Helm chart

This is an Azure Service Operator Docker Hardened Helm chart built from the official upstream Azure Service Operator
Helm chart and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/azure-service-operator`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/Azure/azure-service-operator/tree/main/v2/charts/azure-service-operator](https://github.com/Azure/azure-service-operator/tree/main/v2/charts/azure-service-operator)

### About Azure Service Operator

Azure Service Operator (ASO) is a Kubernetes operator that enables you to provision and manage Azure resources directly
from within your Kubernetes cluster using native Kubernetes tooling. Instead of managing Azure resources through the
Azure portal or CLI, ASO allows you to define Azure resources as Kubernetes Custom Resources and manage them using
familiar tools like `kubectl apply`.

ASO consists of:

- **Custom Resource Definitions (CRDs)** for each Azure service that can be provisioned
- **Kubernetes controller** that synchronizes the desired state defined in Custom Resources with the actual state of
  resources in Azure
- **Code-generated resources** based on Azure OpenAPI specifications, enabling rapid support for new Azure services

Key features of Azure Service Operator:

- **Declarative Azure resource management**: Define Azure infrastructure as Kubernetes manifests using `kubectl apply`
- **GitOps compatibility**: Manage Azure resources through your existing GitOps workflows and CI/CD pipelines
- **Code-generated CRDs**: Automatically generated from Azure REST API specifications, ensuring comprehensive coverage
  of Azure services
- **Rich status information**: View the actual state of Azure resources through Kubernetes, including server-side
  applied defaults
- **Authentication flexibility**: Support for Service Principal, Managed Identity, and Workload Identity authentication
  methods
- **Multi-tenant support**: Operate across multiple Azure tenants and subscriptions from a single operator instance
- **Namespace isolation**: Control which namespaces the operator monitors for Azure resource definitions

ASO v2 (the current stable version) provides significant improvements over v1:

- More uniform resource definitions due to code generation
- Faster support for new Azure API versions
- Clearer resource states through Ready conditions
- Dedicated storage versions for better upgrade experiences

Common use cases include:

- Provisioning Azure databases, storage accounts, and virtual networks from Kubernetes
- Managing Azure resources as part of application deployment manifests
- Implementing infrastructure-as-code practices using Kubernetes-native workflows
- Integrating Azure resource lifecycle with Kubernetes application lifecycle

This Docker Hardened Image packages the Azure Service Operator v2 controller in a secure, minimal container optimized
for production Kubernetes environments.

For more information about Azure Service Operator, visit the official documentation at
https://azure.github.io/azure-service-operator/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Microsoft® and Azure® are registered trademarks of Microsoft Corporation. All rights in the marks are reserved to
Microsoft Corporation. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
