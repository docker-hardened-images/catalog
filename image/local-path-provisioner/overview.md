## About Local Path Provisioner

Local Path Provisioner provides a way for Kubernetes users to utilize local storage on each cluster node. Based on user
configuration, it automatically creates either `hostPath` or `local` based persistent volumes on the appropriate node,
utilizing the Kubernetes Local Persistent Volume feature while offering a simpler solution than the built-in `local`
volume type. It is widely used in lightweight Kubernetes distributions such as K3s and supports per-node storage path
customization via a ConfigMap.

Requires Kubernetes v1.12+.

For more details, see https://github.com/rancher/local-path-provisioner.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
