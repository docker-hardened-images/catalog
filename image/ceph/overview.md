## About Ceph

Ceph is a distributed storage platform that provides object, block, and file interfaces from a single cluster. It is
designed for scale-out deployments and is commonly used to provide resilient storage services for Kubernetes and other
cloud-native environments.

This Docker Hardened Image packages the Ceph runtime used by Rook-managed Ceph daemons together with the core CLI tools
and Python components that Ceph expects at runtime. In this repository, the image is intended primarily for
operator-managed Kubernetes deployments rather than as a single-container standalone Ceph appliance.

For more information, visit https://ceph.io/ and https://rook.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Ceph® is a registered trademark of Red Hat, Inc. Any rights therein are reserved to Red Hat, Inc. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
