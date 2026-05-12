## About SPIFFE Helper

The [SPIFFE Helper](https://github.com/spiffe/spiffe-helper) is a utility for fetching X.509 SVID certificates and JWT
SVIDs from the SPIFFE Workload API, and for keeping them refreshed on disk before they expire. It acts as a sidecar for
workloads that cannot speak the Workload API directly, writing certificate and key files to a shared volume and
optionally signaling or restarting the target process on renewal. SPIFFE Helper is part of the SPIFFE and SPIRE
ecosystem, a set of APIs and tooling for establishing trust between software systems across heterogeneous environments.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

SPIFFE® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

SPIRE® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
