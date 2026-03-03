## About AWS Private CA Issuer

AWS Private CA is an AWS service that can setup and manage private CAs, as well as issue private certificates.

cert-manager is a Kubernetes add-on to automate the management and issuance of TLS certificates from various issuing
sources. It will ensure certificates are valid, updated periodically and attempt to renew certificates at an appropriate
time before expiry.

This project acts as an addon (see https://cert-manager.io/docs/configuration/external/) to cert-manager that signs off
certificate requests using AWS Private CA.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Cert Manager™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation. AWS® and
related marks are registered trademarks of Amazon Web Services. All rights in the mark are reserved to Amazon Web
Services. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
