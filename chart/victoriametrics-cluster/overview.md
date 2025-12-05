## About this Helm chart

This is a VictoriaMetrics Cluster Docker Hardened Helm chart built from the upstream VictoriaMetrics Cluster Helm chart
and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/victoriametrics-vmstorage`
- `dhi/victoriametrics-vmselect`
- `dhi/victoriametrics-vminsert`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://docs.victoriametrics.com/helm/victoria-metrics-cluster](https://docs.victoriametrics.com/helm/victoria-metrics-cluster)

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
