## About KubeVirt Velero Plugin

The KubeVirt Velero Plugin lets Velero back up and restore KubeVirt virtual machines. It adds backup and restore actions
for VirtualMachines, VirtualMachineInstances, DataVolumes, PersistentVolumeClaims, and virt-launcher pods. A backup of a
virtual machine then includes its volumes and the related namespaced objects it needs to restore.

This image is a Velero plugin image. Velero runs it as an initContainer that copies the plugin into the Velero server
pod, so you add it with `velero install --plugins`, `velero plugin add`, or the Velero Helm chart. For more information,
see the [KubeVirt Velero Plugin project](https://github.com/kubevirt/kubevirt-velero-plugin).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

KubeVirt™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. Other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
