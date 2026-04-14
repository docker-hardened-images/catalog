### About SPIFFE SPIRE Server

The **SPIFFE SPIRE Server** is the central authority in a SPIRE deployment and implements the SPIFFE specification for
issuing and managing workload identities. It verifies agent identities through node attestation, manages registration
entries that define workload identities, and issues X.509-SVIDs and JWT-SVIDs within a trust domain. SPIRE Server
persists state in a datastore, supports federation across trust domains, and is designed to run alongside SPIRE Agents
as part of a complete SPIFFE deployment.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Spiffe® and Spire® are registered trademarks of the Linux Foundation. All rights in the marks are reserved to the Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
