## About this Helm chart

This is a Prometheus Pushgateway Helm chart built from the upstream Node Exporter Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/pushgateway`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-pushgateway/README.md](https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-pushgateway/README.md)

## About Pushgateway

The Prometheus Pushgateway accepts metrics from ephemeral or batch jobs and exposes them for scraping by Prometheus. It
provides a simple HTTP API for pushing metrics and supports optional persistence to survive restarts.

Common use cases include short-lived job instrumentation, CI/CD job reporting, and batch-processing metric exposure that
cannot be scraped directly by Prometheus.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® and Prometheus® are all trademarks of the Linux Foundation. All rights in the marks are reserved to the
Linux Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
