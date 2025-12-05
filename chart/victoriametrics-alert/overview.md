## About this Helm chart

This is a VictoriaMetrics Alert Docker Hardened Helm Chart build from the upstream VictoriaMetrics Alert Helm Chart and
using a hardened configuration with Docker Hardened Images.

VictoriaMetrics Alert - executes a list of given MetricsQL expressions (rules) and sends alerts to Alert Manager

The following Docker Hardened Images are used in this Helm chart:

- `dhi/victoriametrics-vmalert`

VictoriaMetrics VMAlert is a component of the VictoriaMetrics monitoring stack. Its primary function is to evaluate
alerting and recording rules against time series data stored in a Prometheus-compatible data source (such as
VictoriaMetrics or Prometheus itself). VMAlert continuously checks these rules and, when conditions are met, sends
alerts to configured alert managers or external systems.

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://docs.victoriametrics.com/helm/victoria-metrics-alert](https://docs.victoriametrics.com/helm/victoria-metrics-alert)

### About VictoriaMetrics

VictoriaMetrics is a high-performance, cost-effective, and scalable time series database and monitoring solution. It is
designed to handle large volumes of time series data with efficiency and reliability, making it ideal for observability
use cases such as metrics collection, monitoring, and alerting.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

VictoriaMetrics® is a trademark of VictoriaMetrics Inc. All rights in the mark are reserved to VictoriaMetrics Inc. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
