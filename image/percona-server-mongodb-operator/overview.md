## About Percona Operator for MongoDB

The Percona Operator for MongoDB automates the deployment and management of Percona Server for MongoDB on Kubernetes. It
creates and reconciles replica sets and sharded clusters from a declarative custom resource, and handles scaling,
storage, user management, backups, restores, and upgrades following Percona's best practices.

This image contains the operator itself plus the `mongodb-healthcheck` binary and the entrypoint scripts that the
operator injects into database pods through an init container.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Percona® is a registered trademark of Percona, LLC. MongoDB® is a registered trademark of MongoDB, Inc. Kubernetes® is a
registered trademark of The Linux Foundation. All rights in the marks are reserved to their respective owners. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
