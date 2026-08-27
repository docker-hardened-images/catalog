## About this Helm chart

This is an OpenTelemetry Operator Docker Hardened Helm chart built from the upstream OpenTelemetry Operator Helm chart
and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/opentelemetry-operator` — operator manager that runs in this chart
- `dhi/opentelemetry-collector` — default image used by the operator when reconciling `OpenTelemetryCollector` resources
- `dhi/opentelemetry-autoinstrumentation-go` — default Go auto-instrumentation agent (used when
  `manager.autoInstrumentation.go.enabled` is true)
- `dhi/busybox` — image for the chart's optional `helm test` hook Pods (`testFramework`)

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/open-telemetry/opentelemetry-helm-charts/blob/main/charts/opentelemetry-operator/README.md](https://github.com/open-telemetry/opentelemetry-helm-charts/blob/main/charts/opentelemetry-operator/README.md)

## About OpenTelemetry Operator

The OpenTelemetry Operator is a Kubernetes operator that manages the lifecycle of OpenTelemetry Collector instances and
auto-instrumentation of workloads using OpenTelemetry instrumentation libraries.

It introduces several custom resources, including `OpenTelemetryCollector` for declaratively managing collector
deployments (as Deployment, DaemonSet, StatefulSet, or Sidecar), `Instrumentation` for automatic injection of
OpenTelemetry SDKs into application pods (Java, Node.js, Python, .NET, Go, Apache HTTPD, Nginx), and `OpAMPBridge` for
managing collectors via the Open Agent Management Protocol.

For more details, visit https://opentelemetry.io/docs/platforms/kubernetes/operator/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

OpenTelemetry® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
