## About this Helm chart

This is a Grafana Tempo Docker Hardened Helm chart built from the upstream Grafana Tempo Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/tempo`
- `dhi/tempo-query` (optional; used when the chart's `tempoQuery.enabled` value is `true`)

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/grafana-community/helm-charts/blob/main/charts/tempo/README.md](https://github.com/grafana-community/helm-charts/blob/main/charts/tempo/README.md)

## About Grafana Tempo

Grafana Tempo is an open-source, high-volume distributed tracing backend. It is deeply integrated with Grafana,
Prometheus, and Loki. Tempo is cost-efficient by storing trace data directly in object storage (S3, GCS, Azure Blob
Storage, or local filesystem), without requiring an indexing layer.

Tempo supports ingesting traces from OpenTelemetry (OTLP), Jaeger, Zipkin, and OpenCensus. Traces can be queried using
TraceQL, Tempo's traces-first query language inspired by Prometheus' PromQL and Grafana Loki's LogQL.

For more details, visit https://grafana.com/docs/tempo/latest/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Grafana® and Tempo are trademarks of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank,
Inc. dba Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
