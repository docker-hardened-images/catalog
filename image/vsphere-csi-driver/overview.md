## About vSphere CSI Driver

The vSphere CSI driver is the Container Storage Interface implementation for VMware vSphere, maintained by the
Kubernetes SIG and Broadcom. It provisions, attaches, and manages vSphere volumes (block and file) for Kubernetes
workloads through vSphere Cloud Native Storage. The same driver binary serves as the CSI controller plugin in the
`vsphere-csi-controller` Deployment and as the CSI node plugin in the `vsphere-csi-node` DaemonSet, where it formats and
mounts volumes using the bundled filesystem tooling (e2fsprogs, xfsprogs, util-linux, nfs-common).

A complete deployment pairs this image with the metadata syncer (`dhi.io/vsphere-csi-syncer`) and the upstream
sig-storage sidecars. The driver connects to vCenter over HTTPS and to the Kubernetes API server, exposes a health
endpoint on port 9808, and serves controller metrics on port 2112.

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
