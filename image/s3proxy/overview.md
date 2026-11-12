## About S3Proxy

S3Proxy exposes an Amazon S3-compatible API in front of a variety of storage backends, including the local filesystem,
Azure Blob Storage, Google Cloud Storage, Backblaze B2, and OpenStack Swift. It uses Apache jclouds to translate S3
requests into the native API of the configured backend, making it useful for testing S3 client code locally, adapting
S3-only applications to other object stores, and adding middleware such as encryption, read-only enforcement, or
eventual-consistency simulation.

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
