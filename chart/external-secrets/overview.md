## About this Helm chart

This is an External Secrets Operator Docker Hardened Helm chart built from the upstream External Secrets Operator Helm
chart and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/external-secrets`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://external-secrets.io/latest/](https://external-secrets.io/latest/)

### About External Secrets Operator

External Secrets Operator is a Kubernetes operator that integrates external secret management systems with Kubernetes.
It synchronizes secrets from external APIs like AWS Secrets Manager, HashiCorp Vault, Google Secrets Manager, and many
others into Kubernetes secrets, enabling secure secret management without storing sensitive data directly in Kubernetes.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
