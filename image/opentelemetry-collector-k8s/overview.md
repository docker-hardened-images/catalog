## About the OpenTelemetry Collector Kubernetes distribution

The OpenTelemetry Collector Kubernetes distribution (otelcol-k8s) is a vendor-neutral telemetry pipeline built to
monitor Kubernetes and the services running in it. It bundles the Kubernetes receivers, processors and extensions (such
as k8s_cluster, kubelet_stats, k8s_attributes and k8s_objects) with OTLP, Prometheus, Jaeger and Zipkin support, and
exports telemetry over OTLP. Official documentation: https://opentelemetry.io/docs/collector/

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

OpenTelemetry™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
