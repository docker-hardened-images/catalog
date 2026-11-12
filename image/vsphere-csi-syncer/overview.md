## About vSphere CSI Syncer

The vSphere CSI syncer is the metadata synchronization component of the vSphere CSI driver, maintained by the Kubernetes
SIG and Broadcom. It runs as a second container in the `vsphere-csi-controller` Deployment and keeps volume metadata
synchronized between Kubernetes and the vSphere Cloud Native Storage inventory, so that vSphere administrators can see
Kubernetes volume context in vCenter. It also provides an optional admission webhook mode for validating storage
operations.

The syncer connects to vCenter over HTTPS and to the Kubernetes API server, supports leader election for multi-replica
controller deployments, and serves Prometheus metrics on port 2113. The CSI driver itself ships as a separate image
(`dhi.io/vsphere-csi-driver`).

For more details, see https://github.com/kubernetes-sigs/vsphere-csi-driver.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes is a registered trademark of The Linux Foundation. VMware and vSphere are trademarks of Broadcom Inc. and/or
its subsidiaries. All rights in those marks are reserved to their respective owners. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
