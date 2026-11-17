## About Hyperledger Fabric Peer

The Hyperledger Fabric Peer image provides a hardened, minimal runtime for running peer nodes in Hyperledger Fabric
networks. Peers host ledger data, execute smart contracts (chaincode), and participate in transaction endorsement and
validation for their organization.

Each peer maintains a local copy of the ledger, exposes query interfaces for client applications, and validates and
commits transactions received from the ordering service. This image is built from upstream Hyperledger Fabric sources
and is intended for secure, production-grade deployments.

For complete usage guidance and tutorials, see the Hyperledger Fabric documentation at
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
