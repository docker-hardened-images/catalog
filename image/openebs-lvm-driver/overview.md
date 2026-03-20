## About OpenEBS LVM LocalPV

OpenEBS LVM LocalPV is a CSI (Container Storage Interface) driver for dynamic provisioning of Kubernetes local
persistent volumes using LVM (Logical Volume Manager). It provides a lightweight storage solution where the volume, LVM
volume group, and the application workload exist on the same node, offering high performance for applications that
require local storage.

The LVM LocalPV driver consists of two main components: the CSI controller that handles incoming provisioning requests
and manages volume lifecycle operations, and the CSI node plugin that executes the actual volume operations on each node
and makes volumes available to pods. This architecture enables dynamic volume provisioning, resizing, and snapshot
capabilities while maintaining the performance benefits of local storage.

OpenEBS LVM LocalPV supports multiple volume modes (filesystem and block), various filesystems (ext4, xfs, btrfs), thin
provisioning for efficient space utilization, and volume resizing without downtime. It is compatible with Kubernetes
1.23 and later, and works across multiple Linux distributions including Debian, Ubuntu, RHEL, CentOS, and others.

For more details, visit https://openebs.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

OpenEBS™ is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
