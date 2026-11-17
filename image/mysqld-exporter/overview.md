## About MySQL Server Exporter

MySQL Server Exporter is the official Prometheus exporter for MySQL and MariaDB. It collects server metrics from
supported MySQL-compatible databases and exposes them on an HTTP endpoint that Prometheus can scrape.

The exporter gathers information such as global status and variables, InnoDB metrics, replication state, performance
schema statistics, table and index I/O waits, and more. It supports scraping standalone instances, replica setups, and
Unix socket connections. Multi-target mode allows one exporter instance to probe multiple databases via the `/probe`
endpoint.

Supported versions include MySQL 5.6+ and MariaDB 10.3+.

For more details, visit https://github.com/prometheus/mysqld_exporter.

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
