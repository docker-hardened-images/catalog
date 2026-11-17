## About Piraeus CSI NFS Server

Piraeus CSI NFS Server is the NFS server component of the LINSTOR CSI driver that enables ReadWriteMany (RWX) volume
access in Kubernetes. It exports LINSTOR-backed volumes via NFS, allowing multiple pods across different nodes to
simultaneously read and write to the same persistent volume. The NFS server pods use DRBD Reactor for high availability,
ensuring continued access to volumes even during node failures. Each pod can manage multiple NFS server instances, and
NFS exports can run on any node that has a replica of the volume deployed.

For more details, visit https://piraeus.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Piraeus Datastore™ is a trademark of The Linux Foundation. All rights in the mark are reserved to The Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
