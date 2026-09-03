## About Forklift virt-v2v

Forklift is a Kubernetes-native toolkit for migrating virtual machines from VMware, oVirt, OpenStack, and other
platforms to KubeVirt. The virt-v2v component wraps libguestfs's virt-v2v tool to convert a VM guest disk during
migration. It installs virtio drivers, adjusts the boot configuration, and prepares the guest to run under QEMU/KVM.

This image packages the virt-v2v conversion tool alongside Forklift's own Go helper binaries that drive and monitor each
conversion, so a migration pipeline can run guest disk conversions as a standalone step in a Kubernetes job or pod.

The image ships the VirtIO drivers that virt-v2v injects into a Windows guest, so Windows and Linux conversions both
work without mounting anything extra. Only the per-architecture driver trees are included, not the full virtio-win ISO,
so the guest-agent installers are not present.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
