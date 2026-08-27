## About this Helm chart

This is a Prometheus Blackbox Exporter Helm chart built from the upstream Prometheus Blackbox Exporter Helm chart and
using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/blackbox-exporter`
- `dhi/prometheus-config-reloader`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-blackbox-exporter/README.md](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-blackbox-exporter/README.md)

## About Prometheus Blackbox Exporter

The Prometheus Blackbox Exporter is a versatile probing tool that allows blackbox monitoring of network endpoints
through multiple protocols including HTTP, HTTPS, DNS, TCP, ICMP, and gRPC. It enables external monitoring of services
by generating Prometheus metrics from probe results, making it essential for monitoring service availability, response
times, TLS certificate expiration, and overall endpoint health. The exporter features a web UI for debugging probes and
supports configuration hot-reloading for dynamic probe management.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Prometheus® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
