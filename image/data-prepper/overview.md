## About Data Prepper

OpenSearch Data Prepper is a server-side data collector that receives, filters, transforms, enriches, and routes
observability data (traces, logs, and metrics) before delivering it to OpenSearch or other sinks. It is built around a
pipeline model: each pipeline connects one or more sources (OpenTelemetry, HTTP, S3, Kafka, and more) through a chain of
processors to one or more sinks, making it straightforward to normalize high-volume telemetry at scale. Data Prepper is
a core component of the OpenSearch observability stack and ships as part of the OpenSearch Project.

The Docker Hardened Data Prepper image ships the upstream-maintained `2.x` release line (currently 2.15.1). The image
includes `gettext-base` (`envsubst`) for rendering `${VAR}` placeholders in pipeline configuration files at container
startup, supporting templated pipeline deployments. Customers running older 2.x point releases (for example, 2.8.0)
should migrate to the current patch to benefit from upstream fixes and continued CVE coverage.

> **Security notice**: The image ships a default `data-prepper-config.yaml` that enables SSL with a self-signed
> `keystore.p12` and HTTP basic authentication with the username `admin` and password `admin`. These defaults are
> intended for initial evaluation only. Before deploying to any non-development environment, replace the keystore with a
> certificate signed by a trusted CA and change the authentication credentials.

For more information about Data Prepper, visit https://opensearch.org.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

All third-party product names and marks referenced here are the property of their respective owners. Any use by Docker
is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
