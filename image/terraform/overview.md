## About Terraform

Terraform is an infrastructure as code tool that lets you define both cloud and on-premises resources in human-readable
configuration files that you can version, reuse, and share.

### Key Features

- **Infrastructure as Code**: Define infrastructure in declarative configuration files using HCL (HashiCorp
  Configuration Language)
- **Multi-Cloud Support**: Manage resources across all major cloud providers and hundreds of SaaS services
- **Execution Plans**: Preview infrastructure changes before applying them with `terraform plan`
- **State Management**: Track the current state of infrastructure to detect drift and manage dependencies
- **Resource Graph**: Build a dependency graph of resources for efficient parallel creation and modification
- **Modular Design**: Write reusable modules to share and compose infrastructure configurations

### Common Use Cases

- **Multi-Cloud Provisioning**: Deploy and manage infrastructure across AWS, Azure, Google Cloud, and other providers
- **Application Infrastructure**: Provision compute, networking, storage, and other resources for applications
- **Compliance and Policy**: Enforce organizational standards with Sentinel policies and OPA integrations
- **Self-Service Infrastructure**: Enable platform teams to offer self-service infrastructure provisioning
- **Kubernetes Management**: Provision and configure Kubernetes clusters and resources

### Supported Providers

Terraform supports thousands of providers through the Terraform Registry, including:

- Amazon Web Services (AWS)
- Microsoft Azure
- Google Cloud Platform (GCP)
- Kubernetes
- Docker
- GitHub
- Datadog
- And many more

### Getting Started

The `terraform` CLI offers a workflow for managing infrastructure:

- `terraform init` - Initialize a working directory with providers and modules
- `terraform plan` - Preview changes to infrastructure
- `terraform apply` - Apply changes to reach desired state
- `terraform destroy` - Remove managed infrastructure
- `terraform validate` - Check configuration syntax and consistency
- `terraform fmt` - Format configuration files to canonical style
- `terraform state` - Inspect and manage state
- `terraform workspace` - Manage multiple environments

This Docker Hardened Image provides a secure, minimal environment for running Terraform operations in containerized
workflows and CI/CD pipelines.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

HashiCorp and Terraform are trademarks of HashiCorp, Inc. This listing is prepared by Docker. All third-party product
names, logos, and trademarks are the property of their respective owners and are used solely for identification. Docker
claims no interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
