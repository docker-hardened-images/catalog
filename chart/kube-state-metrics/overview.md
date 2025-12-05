## About this Helm chart

This is a Kube State Metrics Helm chart built from the upstreamKube State Metrics Helm chartand using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/kube-state-metrics`
- `dhi/kube-rbac-proxy`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[http://github.com/prometheus-community/helm-charts/blob/main/charts/kube-state-metrics/README.md](http://github.com/prometheus-community/helm-charts/blob/main/charts/kube-state-metrics/README.md)

## About kube-state-metrics

kube-state-metrics is an add-on agent for Kubernetes clusters that generates and exposes cluster-level metrics. It
listens to the Kubernetes API server and generates metrics about the state of Kubernetes objects such as deployments,
nodes, pods, and other resources.

The metrics are exposed on an HTTP endpoint (default port 8080 at `/metrics`) in Prometheus format, making it easy to
integrate with monitoring systems like Prometheus and Grafana. kube-state-metrics is particularly useful for alerting on
cluster issues such as pods stuck in Terminating state, querying cluster state like counting pods not ready, and gaining
visibility into the overall health and state of Kubernetes resources.

For more information, visit the official repository: https://github.com/kubernetes/kube-state-metrics

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
