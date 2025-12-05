## About this Helm chart

This is a Vault Docker Helm chart built from the upstream Vault Helm chart and using a hardened configuration with
Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/vault`
- `dhi/vault-k8s`
- `dhi/vault-csi-provider`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/hashicorp/vault-helm](https://github.com/hashicorp/vault-helm)

### About Vault

Vault is HashiCorp's centralized secrets management solution that securely stores, manages, and controls access to
sensitive data such as tokens, passwords, certificates, and encryption keys. It provides a consistent API and tooling
for secret retrieval, encryption-as-a-service, and identity-based access across distributed systems.

Vault supports dynamic secrets that are generated on-demand—like database credentials—along with automated secret
revocation and rotation. Access control is enforced through flexible policy definitions, and all access events are
logged for auditability and compliance.

With its pluggable architecture, Vault integrates into diverse environments including Kubernetes, cloud platforms, and
legacy systems, making it ideal for securing modern application infrastructure and automating secrets management across
development and production environments.

For more information and documentation see https://developer.hashicorp.com/vault.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Vault is a trademark of HashiCorp. All rights in the mark are reserved to HashiCorp. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
