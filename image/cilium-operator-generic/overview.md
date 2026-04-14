## About Cilium Operator Generic

The Cilium Operator Generic is a component within the Cilium ecosystem responsible for managing cluster-wide duties that
should logically be handled once per cluster, rather than once per node. It provides centralized functionality for
Cilium, including identity management, service load balancing, and network policy enforcement. The operator acts as a
control plane component that coordinates Cilium agents running on each node, ensuring consistent policy application and
resource management across the cluster.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Cilium® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
