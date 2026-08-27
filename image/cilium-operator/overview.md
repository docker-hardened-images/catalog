### About Cilium Operator

The Cilium Operator is a specialized component of the Cilium networking and security platform designed to handle
cluster-wide operations and resource management. It manages Cilium-specific operations and resources required for
Cilium's functionality across the entire cluster. This operator handles tasks such as managing IP address allocation,
coordinating CiliumNode resources, garbage collection of stale identities, and maintaining cluster-wide network
policies. It enables Cilium to efficiently manage networking and security operations at scale while providing advanced
network security and observability features. The operator runs as a separate deployment alongside the main Cilium agent,
ensuring that cluster-wide operations are handled efficiently without impacting the core Cilium functionality on
individual nodes.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Cilium® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.

Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
