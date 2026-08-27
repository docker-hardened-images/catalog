## About Dapr Placement Service

The Dapr® Placement Service is a control plane component that manages the distributed placement of actor instances
across a Kubernetes cluster using a consistent hash ring. It uses the Raft consensus protocol to maintain cluster state
and automatically rebalances actor distribution when nodes join or leave the cluster. The placement service enables Dapr
sidecars to locate actor instances reliably, making it essential for any Dapr deployment that uses the virtual actor
model. For more details, see https://docs.dapr.io/concepts/dapr-services/placement/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Dapr® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
