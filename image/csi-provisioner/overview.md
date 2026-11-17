## About csi-provisioner

`csi-provisioner` is a Kubernetes Container Storage Interface (CSI) sidecar component that manages dynamic volume
provisioning. It watches for `PersistentVolumeClaim` (PVC) objects and coordinates volume creation and deletion with CSI
drivers through gRPC calls.

The component monitors the Kubernetes API for PVC creation and deletion requests, calls the CSI driver's `CreateVolume`
and `DeleteVolume` methods, and manages the complete lifecycle of volume provisioning. It supports leader election for
high availability and handles storage class parameters and volume attributes.

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
