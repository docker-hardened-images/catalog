## About OpenTelemetry Target Allocator

The OpenTelemetry Target Allocator is an optional component of the OpenTelemetry Operator that discovers Prometheus
scrape targets (ServiceMonitor/PodMonitor/Prometheus CRs and static configs) and shards them across a fleet of
OpenTelemetry Collector instances. It exposes lightweight HTTP endpoints (default listen address :8080) such as /jobs
and /jobs/{job}/targets which Collectors use to fetch their assigned scrape targets.

For full upstream documentation and configuration examples see:
https://opentelemetry.io/docs/platforms/kubernetes/operator/target-allocator/

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

OpenTelemetry is a project hosted by the Cloud Native Computing Foundation (CNCF). All third-party product names, logos,
and trademarks are the property of their respective owners and are used here for identification purposes only. No
affiliation, sponsorship, or endorsement is implied.
