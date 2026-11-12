## About cert-manager-webhook

cert-manager-webhook is a Kubernetes component that provides an admission webhook used by cert-manager to validate and
mutate cert-manager resources. It ensures that Certificate, Issuer, and related custom resources created in the cluster
are syntactically and semantically valid before being persisted by the Kubernetes API server.

As part of the cert-manager ecosystem, the webhook enforces policy and consistency across cert-manager resources. It
performs admission control checks, applies default values where necessary, and validates configuration details to
prevent misconfigurations that could lead to certificate issuance errors or security issues.

The cert-manager webhook is deployed automatically alongside cert-manager and communicates securely with the Kubernetes
API server using TLS. Certificates used by the webhook are automatically managed and renewed by cert-manager itself,
ensuring ongoing secure communication without manual certificate handling.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Cert Manager™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
