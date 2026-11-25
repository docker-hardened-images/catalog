## About Cloud SQL Auth Proxy

The Cloud SQL Auth Proxy opens authenticated, encrypted connections from a local port to Cloud SQL for MySQL,
PostgreSQL, and SQL Server. It runs beside an application as a sidecar and holds the connection to Cloud SQL while the
application uses that local port. This image replaces the upstream images `gcr.io/cloud-sql-connectors/cloud-sql-proxy`
(current line) and `gcr.io/cloudsql-docker/gce-proxy` (v1 line). The project is published at
https://github.com/GoogleCloudPlatform/cloud-sql-proxy under the Apache-2.0 license.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Google Cloud™ and Google Cloud Platform™ are trademarks of Google LLC. All rights in the marks are reserved to Google
LLC. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
