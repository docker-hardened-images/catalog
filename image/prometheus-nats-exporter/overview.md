## About Prometheus NATS Exporter

Prometheus NATS Exporter is a Prometheus exporter for NATS server metrics. It collects monitoring information from NATS
server endpoints and exposes them at an HTTP endpoint that Prometheus can scrape.

The exporter aggregates metrics from various NATS monitoring endpoints including varz (general server info), connz
(connections), subz (subscriptions), routez (routes), healthz (health status), and JetStream statistics. This enables
comprehensive monitoring of NATS infrastructure in Prometheus-based observability stacks.

For more details, visit https://github.com/nats-io/prometheus-nats-exporter.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

NATS™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Prometheus® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
