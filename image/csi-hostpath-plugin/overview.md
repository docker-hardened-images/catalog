## About CSI Hostpath Plugin

`csi-hostpath-plugin` is a Kubernetes Container Storage Interface (CSI) driver that uses the host's filesystem as
storage. It provides persistent volume functionality by mounting directories from the host node into containers, making
it ideal for testing, development, and single-node Kubernetes deployments.

The driver implements the full CSI specification and supports dynamic volume provisioning, volume expansion, and
snapshot operations. It is commonly used in local development environments, CI/CD pipelines, and testing scenarios where
a full storage backend is not required.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
