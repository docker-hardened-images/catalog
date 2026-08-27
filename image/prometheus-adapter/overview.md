## About Prometheus Adapter

Prometheus Adapter is an implementation of the Kubernetes
[Custom](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/#support-for-custom-metrics)
and
[External](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/#support-for-metrics-apis)
Metrics APIs. It allows the Horizontal Pod Autoscaler (HPA) and Vertical Pod Autoscaler (VPA) to scale workloads based
on metrics stored in Prometheus, by translating Prometheus queries into the metrics that the Kubernetes API server
exposes.

The adapter runs as a Kubernetes API server extension: it registers the custom.metrics.k8s.io and
external.metrics.k8s.io API groups and serves metric values by querying Prometheus. It uses in-cluster configuration by
default to talk to the Kubernetes API and to your Prometheus instance, and supports configurable discovery and metric
mapping rules so you can expose the right Prometheus metrics to HPAs.

For configuration details and walkthroughs, see the
[Prometheus Adapter documentation](https://github.com/kubernetes-sigs/prometheus-adapter).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Prometheus® and Kubernetes® are a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
