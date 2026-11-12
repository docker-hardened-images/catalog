## About Debezium Connect

Debezium is a change data capture (CDC) platform that streams row-level database changes into Kafka topics. This image
packages Debezium's connector plugins on a Kafka Connect distributed worker, so it can run as a standalone Kafka Connect
cluster node. It serves the Kafka Connect REST API on port 8083, backed by a Kafka broker you provide via
`CONNECT_BOOTSTRAP_SERVERS`.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks, including Debezium, Apache
Kafka, MySQL, MariaDB, PostgreSQL, MongoDB, SQL Server, and Oracle, are the property of their respective owners and are
used solely for identification. Docker claims no interest in those marks, and no affiliation, sponsorship, or
endorsement is implied.
