## About this Helm chart

This is a MongoDB Docker Helm chart built from the MongoDB chart in
[docker-hardened-images/helm-charts](https://github.com/docker-hardened-images/helm-charts) while using Docker Hardened
Images for all container references.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/mongodb`
- `dhi/mongodb-exporter`
- `dhi/nginx`
- `dhi/kubectl`
- `dhi/bash` (replacing legacy init images where applicable)

Upstream chart source: https://github.com/docker-hardened-images/helm-charts/tree/main/mongodb

### About MongoDB

MongoDB is a source-available cross-platform document-oriented database.

## Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

MongoDB®, Mongo®, and the leaf logo are registered trademarks of MongoDB, Inc. All rights in the mark are reserved to
MongoDB, Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
