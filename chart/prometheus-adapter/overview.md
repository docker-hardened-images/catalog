## About this Helm chart

This is a Prometheus Adapter Helm chart built from the upstream
[prometheus-community/prometheus-adapter](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-adapter)
Helm chart and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/prometheus-adapter`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[prometheus-community helm-charts - prometheus-adapter](https://github.com/prometheus-community/helm-charts/blob/main/charts/prometheus-adapter/README.md)

## About Prometheus Adapter

Prometheus Adapter implements the custom.metrics.k8s.io and external.metrics.k8s.io APIs for Kubernetes, enabling
Horizontal Pod Autoscaler (HPA) and Vertical Pod Autoscaler (VPA) to use metrics from Prometheus.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Kubernetes® and Prometheus® are trademarks of the Linux Foundation. All rights in the marks are reserved to the Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
