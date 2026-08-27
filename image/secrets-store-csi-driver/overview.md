## About Secrets Store CSI Driver

The Secrets Store CSI Driver mounts secrets, keys, and certificates from external stores — AWS Secrets Manager, Azure
Key Vault, GCP Secret Manager, HashiCorp Vault — into Kubernetes pods as volumes via the CSI volume API. It runs as a
DaemonSet on every node, is provider-agnostic, and supports automatic secret rotation and optional syncing into native
Kubernetes Secrets.

For more details, visit https://secrets-store-csi-driver.sigs.k8s.io.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
