## About Azure Key Vault Controller

Azure Key Vault Controller is the controller component of the [akv2k8s](https://akv2k8s.io) project from Sparebanken
Vest. It watches `AzureKeyVaultSecret` custom resources and synchronizes the referenced secrets, certificates, and keys
from Azure Key Vault into native Kubernetes `Secret` objects, so workloads can consume them through `envFrom`,
`secretKeyRef`, or projected volumes without persisting Azure credentials in the cluster or running custom sync jobs.

Requires Kubernetes v1.16+.

For more details, see https://github.com/SparebankenVest/azure-key-vault-to-kubernetes.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. Microsoft® and Azure® are registered trademarks of
Microsoft Corporation. All rights in those marks are reserved to their respective owners. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
