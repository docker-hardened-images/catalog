## About Virt Handler

The Virt Handler is a component of [KubeVirt](https://github.com/kubevirt/kubevirt), which extends Kubernetes with
virtualization capabilities.

The virt-handler runs as a DaemonSet on each node and manages the lifecycle of virtual machine processes, communicating
with libvirt and QEMU to start, stop, and monitor VMs.

For more details, see https://github.com/kubevirt/kubevirt.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

KubeVirt® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
