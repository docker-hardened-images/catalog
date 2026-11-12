## About CSI-Addons Sidecar

`csi-addons-k8s-sidecar` is the Kubernetes CSI-Addons sidecar component. It runs alongside a Container Storage Interface
(CSI) driver and connects to the driver's CSI-Addons socket over gRPC, exposing advanced storage operations to the
CSI-Addons controller. Supported operations include reclaim space, network fence, volume replication, encryption key
rotation and volume group management.

The sidecar registers a `CSIAddonsNode` object for the driver it accompanies, serves the CSI-Addons gRPC services to the
controller, and optionally reports volume condition. It supports leader election so that only one sidecar handles
controller-service requests for a given driver at a time. The image also ships the `csi-addons` administration command
for interacting with CSI-Addons resources.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
