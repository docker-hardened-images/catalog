## About this Helm chart

This is an ClickHouse Operator Docker Helm chart built from the upstream ClickHouse Operator Helm chart and using a
hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/clickhouse-operator`
- `dhi/clickhouse-metrics-exporter`
- `dhi/clickhouse-server`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/Altinity/clickhouse-operator/tree/master/deploy/helm](https://github.com/Altinity/clickhouse-operator/tree/master/deploy/helm)

### About ClickHouse

ClickHouse is an open-source column-oriented DBMS (columnar database management system) for online analytical processing
(OLAP) that allows users to generate analytical reports using SQL queries in real-time.

ClickHouse works 100-1000x faster than traditional database management systems, and processes hundreds of millions to
over a billion rows and tens of gigabytes of data per server per second. With a widespread user base around the globe,
the technology has received praise for its reliability, ease of use, and fault tolerance.

For more information and documentation see https://clickhouse.com/⁠.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

ClickHouse is a trademark of ClickHouse, Inc. All rights in the mark are reserved to ClickHouse, Inc. Any use by Docker
is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
