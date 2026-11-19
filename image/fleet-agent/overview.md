## About Fleet Agent

Fleet is a GitOps and HelmOps engine for managing deployments across one or many Kubernetes® clusters. The Fleet Agent
runs on each managed cluster, registers with the Fleet controller on the management cluster, and applies the workloads
that Fleet resolves from Git repositories, Helm charts, or Kustomize overlays.

This image contains the `fleetagent` binary built from [`rancher/fleet`](https://github.com/rancher/fleet). See the
[upstream documentation](https://fleet.rancher.io/) for installation and configuration.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes is a registered trademark of The Linux Foundation. The upstream Fleet project does not state a trademark
claim for its name. All other product names, logos, and trademarks are the property of their respective owners and are
used solely for identification. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
