## About Hyperledger Fabric CA

Hyperledger Fabric CA is a hardened, minimal image that bundles the official Certificate Authority for managing
identities and certificates in Hyperledger Fabric networks. It includes fabric-ca-server and fabric-ca-client to support
identity lifecycle management, enrollment, registration, and revocation workflows. Use fabric-ca-server to operate a
Certificate Authority that issues X.509 certificates and manages the public key infrastructure (PKI) for network
participants. The fabric-ca-client utility enables identity enrollment, certificate renewal, registration of new
identities, revocation of compromised certificates, and retrieval of CA information. Together, these tools provide
comprehensive identity and access management capabilities essential for securing Fabric blockchain networks.

This image targets operators and CI pipelines that need reliable, reproducible Fabric tooling without a full peer or
orderer runtime. Binaries are built from upstream source with embedded version and commit metadata for precise
traceability. For complete usage guidance and tutorials, see the Hyperledger Fabric documentation at
https://hyperledger-fabric.readthedocs.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Hyperledger® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
