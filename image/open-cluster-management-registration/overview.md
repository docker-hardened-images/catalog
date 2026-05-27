## About Open Cluster Management Registration

Open Cluster Management Registration is a component of the Open Cluster Management (OCM) project that handles spoke
cluster registration with the hub. The registration binary includes hub-side controllers, the spoke registration agent,
and the registration webhook server.

It supports three subcommands: `controller`, `agent`, and `webhook-server`. Hub deployments typically run the
`controller` subcommand, while managed clusters run the `agent` subcommand.

For more details, visit https://github.com/open-cluster-management-io/ocm.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Open Cluster Management™ is a trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
