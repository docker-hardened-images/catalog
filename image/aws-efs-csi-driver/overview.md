## About AWS EFS CSI Driver

The AWS EFS CSI Driver implements the
[Container Storage Interface (CSI)](https://github.com/container-storage-interface/spec) specification for
[Amazon Elastic File System (EFS)](https://aws.amazon.com/efs/), enabling Kubernetes clusters to use EFS as persistent
storage. It supports both dynamic provisioning (creating EFS access points on demand) and static provisioning (mounting
existing EFS file systems), making it straightforward to share persistent, scalable NFS-based storage across pods and
nodes in a Kubernetes cluster.

This Docker Hardened Image provides the `aws-efs-csi-driver` binary built from source on Debian 13, with runtime tools
for NFS4 mounting (`mount`, `nfs-common`) and encryption in transit (`stunnel4`). A FIPS-compliant variant is also
available for regulated environments.

*Everything below here is boilerplate and should be included verbatim!!!!! Be sure to remove this comment and keep
everything below this comment exactly as is.*

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Amazon Web Services, AWS, and Amazon EFS are trademarks or registered trademarks of Amazon.com, Inc. or its affiliates.
All rights in the marks are reserved to Amazon.com, Inc. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.
