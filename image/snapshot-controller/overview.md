## About snapshot-controller

`snapshot-controller` is a Kubernetes controller that manages volume snapshots by watching `VolumeSnapshot` and
`VolumeSnapshotContent` objects. It coordinates snapshot creation and deletion operations with CSI drivers through the
Kubernetes API, ensuring snapshots are properly created, bound, and cleaned up according to user requests.

The controller runs as a Deployment in the cluster and handles the complete lifecycle of volume snapshots, working in
conjunction with CSI sidecars like `csi-snapshotter` to provide snapshot functionality for storage systems.

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
