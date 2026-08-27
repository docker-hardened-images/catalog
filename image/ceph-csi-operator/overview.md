## About Ceph CSI Operator

Ceph CSI Operator is a Kubernetes operator that deploys and manages the Ceph CSI drivers. It watches OperatorConfig and
Driver custom resources and reconciles the controller and node plugin workloads that provide RBD, CephFS, NFS, and
NVMe-oF storage to Kubernetes pods, removing the need to manage the CSI driver manifests by hand.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Ceph® is a registered trademark of Red Hat, Inc. Any rights therein are reserved to Red Hat, Inc. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
