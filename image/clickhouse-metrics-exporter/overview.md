## About clickhouse-metrics-exporter

`clickhouse-metrics-exporter` is Altinity's official Prometheus metrics exporter for the ClickHouse Operator that
provides comprehensive monitoring and observability for ClickHouse clusters running on Kubernetes. It operates as a
companion service to the operator, automatically discovering managed ClickHouse clusters and exposing their operational
metrics through a Prometheus-compatible HTTP endpoint.

The system works by watching ClickHouse Installation (CHI) resources in the Kubernetes cluster, connecting directly to
ClickHouse nodes to collect metrics, and serving them at `/metrics` endpoint for Prometheus scraping. It supports
parallel metric collection across multiple clusters and hosts, handles both HTTP and HTTPS connections automatically
based on cluster configuration, and provides real-time visibility into ClickHouse performance, table statistics,
replication status, and system health.

This integration enables organizations to implement comprehensive monitoring strategies for their ClickHouse deployments
while maintaining Kubernetes-native patterns, supporting use cases like performance optimization, capacity planning,
alerting on replication lag, and tracking query patterns across development and production environments without
requiring custom monitoring solutions or manual metric configuration.

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
