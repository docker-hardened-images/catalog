## About Open Cluster Management Work

Open Cluster Management Work is a component of the Open Cluster Management (OCM) project that dispatches Kubernetes
manifests to managed clusters via the ManifestWork API. It enables hub clusters to distribute and manage workloads
across multiple managed clusters.

The Work agent runs on managed clusters and reconciles ManifestWork resources, applying the specified Kubernetes
manifests and reporting their status back to the hub cluster. It supports three subcommands: `agent`, `manager`, and
`webhook-server`.

For more details, visit https://github.com/open-cluster-management-io/ocm.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
