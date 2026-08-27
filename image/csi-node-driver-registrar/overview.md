## About csi-node-driver-registrar

The node-driver-registrar is a sidecar container that registers the CSI driver with Kubelet using the kubelet plugin
registration mechanism.

This is necessary because Kubelet is responsible for issuing CSI `NodeGetInfo`, `NodeStageVolume`, `NodePublishVolume`
calls. The `node-driver-registrar` registers your CSI driver with Kubelet so that it knows which Unix domain socket to
issue the CSI calls on.

For more information, visit the official repository: https://github.com/kubernetes-csi/node-driver-registrar

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
