## About this Helm chart

This is a Grafana Alloy Docker Hardened Helm chart built from the upstream Grafana Alloy Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/alloy`
- `dhi/prometheus-config-reloader`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/grafana/alloy/blob/main/operations/helm/charts/alloy/README.md](https://github.com/grafana/alloy/blob/main/operations/helm/charts/alloy/README.md)

## About Grafana Alloy

Grafana Alloy is a flexible and extensible distribution of the OpenTelemetry Collector, developed by Grafana Labs. It
enables you to collect, transform, and export telemetry data from a wide range of sources to observability platforms
such as Grafana, Loki, Tempo, and Prometheus.

Alloy supports a modular pipeline architecture and includes a curated set of receivers, processors, and exporters for
common telemetry systems. It is well-suited for organizations that want to standardize and simplify their observability
pipelines.

For more details, visit https://grafana.com/oss/alloy-opentelemetry-collector/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Grafana® Alloy is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank, Inc.
dba Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
