## About PostgreSQL Exporter

PostgreSQL Exporter is a Prometheus exporter for monitoring PostgreSQL database metrics. It collects internal metrics
from PostgreSQL instances and exposes them at an HTTP endpoint that Prometheus can scrape.

PostgreSQL Exporter exports information about database connections, transactions, locks, replication status, table and
index statistics, query performance, and more. It supports PostgreSQL versions 9.6 and later, and can be configured to
monitor multiple databases and collect custom metrics using SQL queries.

For more details, visit https://github.com/prometheus-community/postgres_exporter.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

PostgreSQL® is a trademark of PostgreSQL Community Association of Canada. All rights in the mark are reserved to
PostgreSQL Community Association of Canada. Any use by Docker is for referential purposes only and does not indicate
sponsorship, endorsement, or affiliation.

Prometheus® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
