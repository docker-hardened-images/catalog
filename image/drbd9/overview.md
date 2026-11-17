## About DRBD9

DRBD9 (Distributed Replicated Block Device) is a Linux kernel module that provides block-level replication for
high-availability storage systems. This Docker Hardened Image contains the DRBD kernel modules and an entrypoint script
that loads them into the host kernel, enabling DRBD functionality for containerized applications.

The image is designed to be used as an init container in Kubernetes deployments, particularly with LinstorSatellite
pods, to provide DRBD kernel module support before other containers start. It handles kernel module compilation,
loading, and dependency resolution automatically.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

DRBD® is a registered trademark of LINBIT HA-Solutions GmbH. All rights in the mark are reserved to LINBIT HA-Solutions
GmbH. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
