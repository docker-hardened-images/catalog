## About this Helm chart

This is an OpenTelemetry Collector Docker Hardened Helm chart built from the upstream OpenTelemetry Collector Helm chart
and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/opentelemetry-collector`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-collector]https://github.com/open-telemetry/opentelemetry-helm-charts/tree/main/charts/opentelemetry-collector)

## About the OpenTelemetry Collector

The OpenTelemetry Collector (otelcol) is a vendor-agnostic telemetry pipeline that receives, processes, and exports
traces, metrics, and logs. It is commonly deployed as a standalone gateway or an agent alongside applications to
centralize telemetry collection, apply processing (sampling, batching), and forward data to backends such as Prometheus,
Tempo, Jaeger, or commercial APMs. Official documentation: https://opentelemetry.io/docs/collector/installation/

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
