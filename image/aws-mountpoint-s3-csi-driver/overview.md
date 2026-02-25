## About AWS Mountpoint S3 CSI Driver

The AWS Mountpoint for Amazon S3 CSI Driver provides Container Storage Interface (CSI) support for mounting Amazon S3
buckets as storage volumes in Kubernetes clusters. Built on Mountpoint for Amazon S3, it presents S3 buckets as a file
system interface accessible by containers, enabling applications to read and write S3 objects using standard file
operations.

The driver is optimized for high-throughput access to large objects and supports features like static provisioning,
mount options, Mountpoint Pod sharing for improved resource utilization, and managed local caching. It implements CSI
Specification v1.9.0 and is compatible with Kubernetes v1.25+. Note that Mountpoint does not implement full POSIX file
system semantics - it's designed for workloads that need high-performance sequential reads and writes rather than random
access or file modifications.

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
