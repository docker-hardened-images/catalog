## About Cluster API Controller

Cluster API is a Kubernetes sub-project (SIG Cluster Lifecycle) that provides declarative, Kubernetes-style APIs to
provision, upgrade, and operate Kubernetes clusters across infrastructure providers. This image packages the core
controller manager (`cluster-api-controller`), which reconciles the core Cluster API resources (`Cluster`, `Machine`,
`MachineSet`, `MachineDeployment`, `MachineHealthCheck`, and related contracts) and coordinates bootstrap,
control-plane, and infrastructure providers.

The controller is designed to run inside a management cluster, typically installed with `clusterctl` alongside a
bootstrap provider, a control-plane provider, and one or more infrastructure providers. It serves validating and
defaulting webhooks (port 9443), health probes (port 9440), and a diagnostics/metrics endpoint (port 8443).

For more details, see https://cluster-api.sigs.k8s.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. Cluster API is a Kubernetes sub-project, and its name and
artwork are made available under The Linux Foundation trademark usage guidelines. All rights in those marks are reserved
to The Linux Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
