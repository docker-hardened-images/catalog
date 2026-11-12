## About AWS EBS CSI Driver

The AWS EBS CSI Driver provides Container Storage Interface (CSI) support for Amazon Elastic Block Store (EBS) volumes
in Kubernetes clusters. It enables dynamic and static provisioning of EBS volumes, volume snapshots, volume resizing,
and topology-aware volume scheduling.

The driver implements the CSI specification and integrates with the Kubernetes storage subsystem to provide persistent
storage for stateful workloads running on Amazon EKS or self-managed Kubernetes clusters on AWS. It supports all EBS
volume types including gp3, gp2, io1, io2, st1, and sc1, with features like encryption, multi-attach, and volume
expansion.

The driver runs as two components: a controller component that handles volume lifecycle operations (create, delete,
snapshot) and a node component that handles volume attachment and mounting on each Kubernetes node. This architecture
enables scalable and reliable storage provisioning for containerized applications.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. Amazon Web Services, AWS, and the AWS logo are trademarks
of Amazon.com, Inc. or its affiliates. All rights in these marks are reserved to their respective owners. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
