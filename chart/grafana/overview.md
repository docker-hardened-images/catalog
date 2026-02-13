## About this Helm chart

This is a Grafana Docker Hardened Helm chart built from the upstream Grafana Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/grafana`
- `dhi/grafana-image-renderer`
- `dhi/bats`
- `dhi/busybox`
- `dhi/curl`
- `dhi/k8s-sidecar`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/grafana-community/helm-charts/blob/main/charts/grafana/README.md](https://github.com/grafana-community/helm-charts/blob/main/charts/grafana/README.md)

## About Grafana

Grafana Open Source (OSS) lets you query, visualize, and explore metrics, logs, and traces from a variety of data
sources. With Grafana's data source plugins, you can connect to systems like Prometheus, CloudWatch, Loki,
Elasticsearch, Postgres, GitHub, and many others. Grafana OSS helps you build live dashboards featuring interactive
graphs and visualizations to monitor and better understand your data.

For more details, visit https://grafana.com/docs/grafana/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Grafana® is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank, Inc. dba
Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
