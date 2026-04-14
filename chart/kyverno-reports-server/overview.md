## About this Helm chart

This is a Kyverno reports server Helm chart built from the upstream Kyverno reports server Helm chart and using a
hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/kyverno-reports-server`
- `dhi/kubectl`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/kyverno/reports-server/blob/main/charts/reports-server/README.md](https://github.com/kyverno/reports-server/blob/main/charts/reports-server/README.md)

## About Kyverno Reports Server

Reports server provides a scalable solution for storing policy reports and cluster policy reports. It moves reports out
of etcd and stores them in a PostgreSQL database instance.

For more details, visit https://github.com/kyverno/reports-server.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kyverno® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
