## About SMB CSI Driver

The SMB CSI Driver is a Kubernetes Container Storage Interface (CSI) driver that lets pods mount SMB/CIFS shares from an
existing SMB server, such as a Windows file server or Samba. It supports statically provisioned volumes and dynamic
provisioning, where each PersistentVolumeClaim gets its own subdirectory on the share.

The same `smbplugin` binary runs as the controller, which creates and deletes volume subdirectories, and as the node
plugin, which mounts shares into pods with `mount.cifs`, including Kerberos-authenticated mounts. For more information,
see the [upstream project](https://github.com/kubernetes-csi/csi-driver-smb).

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
