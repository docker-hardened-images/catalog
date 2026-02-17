## About this Helm chart

This is a Kube Prometheus Stack Helm chart built from the upstream prometheus-community kube-prometheus-stack Helm chart
and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Helm charts are used in this Helm chart:

- `dhi/kube-state-metrics-chart`
- `dhi/node-exporter-chart`
- `dhi/grafana-chart`

The following Docker Hardened Images are used in this Helm chart:

- `dhi/busybox`
- `dhi/kubectl`
- `dhi/alertmanager`
- `dhi/prometheus-operator-admission-webhook`
- `dhi/kube-webhook-certgen`
- `dhi/prometheus-operator`
- `dhi/prometheus-config-reloader`
- `dhi/thanos`
- `dhi/prometheus`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md](https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/README.md)

## About Kube Prometheus Stack

kube-prometheus-stack collects Kubernetes manifests, Grafana dashboards, and Prometheus rules combined with
documentation and scripts to provide easy to operate end-to-end Kubernetes cluster monitoring with Prometheus using the
Prometheus Operator. It includes Prometheus, Alertmanager, Grafana, node-exporter, and kube-state-metrics.

For more details, visit https://github.com/prometheus-operator/kube-prometheus.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® and Prometheus® are trademarks of the Linux Foundation. All rights in the marks are reserved to the Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
