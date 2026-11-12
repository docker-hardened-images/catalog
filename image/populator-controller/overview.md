## About Forklift Populator Controller

The Forklift Populator Controller is the volume population component of the
[Forklift](https://github.com/kubev2v/forklift) VM migration toolkit for KubeVirt. It is a Kubernetes controller that
watches volume populator custom resources and, for each one, launches the provider-specific populator pod that copies
virtual machine disk data into the target PersistentVolumeClaim.

The controller reconciles three custom resource kinds, one per migration source, and drives the Kubernetes volume
populator machinery for each:

- **OvirtVolumePopulator** — transfers disks from oVirt / Red Hat Virtualization engines
- **OpenstackVolumePopulator** — transfers images from OpenStack Glance
- **VSphereXcopyVolumePopulator** — offloads VMware VMDK copies to supported storage arrays

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. Use of this trademark does not imply endorsement by The
Linux Foundation or the Kubernetes project.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
