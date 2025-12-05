## About this Helm chart

This is a Prometheus Node Exporter Helm chart built from the upstream Node Exporter Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/node-exporter`
- `dhi/kube-rbac-proxy`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-node-exporter/README.md](https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-node-exporter/README.md)

## About node-exporter

Prometheus node_exporter is a small utility that exposes hardware- and OS-level metrics (CPU, memory, filesystem,
network, and more) from a host to Prometheus. It is commonly deployed as an agent on servers or as a container that is
bound to host namespaces to collect host metrics.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® and Prometheus® are a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
