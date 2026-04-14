### About SPIFFE SPIRE Agent

The SPIFFE SPIRE Agent is a workload attestation component in a SPIRE deployment that runs alongside workloads on each
node. It performs node and workload attestation, requests X.509-SVIDs and JWT-SVIDs from the SPIRE Server based on
workload selectors, and exposes the SPIFFE Workload API for workloads to retrieve their identities. The agent caches
identities locally, automatically rotates SVIDs before expiration, and maintains a secure connection to the SPIRE
Server, making it an essential component for zero-trust security in cloud-native environments.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Spiffe® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
