## About Hyperledger Fabric Tools

Hyperledger Fabric Tools is a hardened, minimal image that bundles the official CLI utilities for operating Hyperledger
Fabric networks. It includes configtxgen, configtxlator, cryptogen, discover, ledgerutil, and osnadmin to support
network bootstrapping, inspection, and administration workflows. Use it to generate channel artifacts and genesis blocks
(configtxgen), translate and inspect configurations (configtxlator), and create or extend cryptographic material
(cryptogen). The discover client queries peers for topology, configuration, and endorsement plans, while ledgerutil
helps analyze and verify ledger snapshots. The osnadmin utility provides administration commands for ordering service
nodes (OSNs), including channel join, list, update, and fetch operations.

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
