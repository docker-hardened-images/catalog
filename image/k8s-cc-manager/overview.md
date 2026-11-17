## About NVIDIA k8s-cc-manager

NVIDIA k8s-cc-manager is a Kubernetes component that enables and manages GPU Confidential Computing (CC) mode, and
Protected PCIe (PPCIe) multi-GPU mode, on supported NVIDIA GPUs. It runs as a DaemonSet on GPU nodes and watches the
`nvidia.com/cc.mode` node label. When the label changes, it optionally evicts NVIDIA GPU Operator components, applies
the requested mode directly against the GPU hardware, and reschedules the operator components. It reports progress back
to the node through the `nvidia.com/cc.mode.state` and `nvidia.com/cc.ready.state` labels.

This is the Python implementation of the manager. It uses the official Kubernetes Python client to watch node labels and
the vendored NVIDIA `gpu-admin-tools` library to query and set CC/PPCIe mode and to reset GPUs over PCI. Because it
pokes GPU PCI registers and resets devices, the container must run as root and privileged, with host `/sys` and `/dev`
mounted.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

NVIDIA® is a registered trademark of NVIDIA Corporation. All rights in the mark are reserved to NVIDIA Corporation. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
