## About this Helm chart

This is a Grafana Loki Docker Hardened Helm chart built from the upstream Grafana Loki Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Helm charts are used in this Helm chart:

- `dhi/grafana-rollout-operator-chart`

The following Docker Hardened Images are used in this Helm chart:

- `dhi/loki`
- `dhi/loki-canary`
- `dhi/loki-helm-test`
- `dhi/nginx`
- `dhi/k8s-sidecar`
- `dhi/memcached`
- `dhi/memcached-exporter`
- `dhi/access-log-exporter`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/grafana/loki/blob/main/production/helm/loki/README.md](https://github.com/grafana/loki/blob/main/production/helm/loki/README.md)

## About Grafana Loki

Grafana Loki is a log aggregation tool built for scalability, high availability, and multi-tenancy. Inspired by
Prometheus, it focuses on simplicity and cost-efficiency. Instead of indexing the full content of logs, Loki organizes
them using labels attached to each log stream.

For more details, visit https://grafana.com/oss/loki/⁠.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Grafana® Loki® is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank, Inc.
dba Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
