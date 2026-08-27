## About cert-manager-acmesolver

cert-manager-acmesolver is a lightweight, short-lived component of [cert-manager](https://cert-manager.io) responsible
for solving ACME challenges required for automated TLS certificate issuance.

When a certificate request uses an ACME issuer (such as Let’s Encrypt), the acmesolver temporarily runs within the
cluster to respond to HTTP-01 or DNS-01 validation requests, proving domain ownership to the certificate authority.

Once validation succeeds, the acmesolver reports the result back to cert-manager and is automatically cleaned up,
ensuring a secure, ephemeral, and automated certificate management workflow in Kubernetes.

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
