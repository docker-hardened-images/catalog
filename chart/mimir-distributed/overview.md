## About this Helm chart

This is a Grafana Mimir Docker Hardened Helm chart built from the upstream Grafana Mimir `mimir-distributed` Helm chart
and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Helm charts are used in this Helm chart:

- `dhi/grafana-rollout-operator-chart`

The following Docker Hardened Images are used in this Helm chart:

- `dhi/mimir`
- `dhi/kafka`
- `dhi/nginx`
- `dhi/memcached`
- `dhi/memcached-exporter`

The upstream chart can also deploy MinIO for demo purposes. MinIO is not part of this chart, so you need to configure an
object storage backend yourself.

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/grafana/mimir/blob/main/operations/helm/charts/mimir-distributed/README.md](https://github.com/grafana/mimir/blob/main/operations/helm/charts/mimir-distributed/README.md)

## About Grafana Mimir

Grafana Mimir is an open source, horizontally scalable, highly available, multi-tenant, long-term storage backend for
Prometheus metrics. It provides unlimited cardinality and long-term metric retention with a fully Prometheus-compatible
query API, built-in multi-tenancy, and support for high-availability clustering.

For more details, visit https://grafana.com/docs/mimir/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Grafana® Mimir is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank, Inc.
dba Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
