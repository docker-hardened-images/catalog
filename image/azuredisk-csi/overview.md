## About Azure Disk CSI Driver

The Azure Disk CSI driver is the Container Storage Interface implementation for Azure managed disks, maintained by the
Kubernetes SIG community. It lets Kubernetes provision, attach, snapshot, clone, resize and mount Azure Disk volumes for
workloads running on AKS or self-managed clusters on Azure. The same binary serves as the CSI controller plugin and as
the CSI node plugin, where it formats and mounts disks using the bundled filesystem tooling (util-linux, e2fsprogs,
xfsprogs, btrfs-progs).

For more details, see https://github.com/kubernetes-sigs/azuredisk-csi-driver.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes is a registered trademark of The Linux Foundation. Microsoft and Azure are trademarks of the Microsoft group
of companies. All rights in those marks are reserved to their respective owners. Any use by Docker is for referential
purposes only and does not indicate sponsorship, endorsement, or affiliation.
