## About csi-attacher

`csi-attacher` is a Kubernetes Container Storage Interface (CSI) sidecar component that manages volume attachment and
detachment operations in Kubernetes clusters. It operates as part of the CSI driver controller pod, watching for
`VolumeAttachment` objects created by the Kubernetes control plane and coordinating volume attachment/detachment with
CSI drivers through gRPC calls.

The component monitors the Kubernetes API for volume attachment requests, calls the CSI driver's
`ControllerPublishVolume` and `ControllerUnpublishVolume` methods, and handles the complete lifecycle of volume
attachments. It supports leader election for high availability deployments and integrates seamlessly with the Kubernetes
storage subsystem.

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
