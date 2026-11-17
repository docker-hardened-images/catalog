## About Jaeger

Jaeger is an open source, end-to-end distributed tracing system. It is used to monitor and troubleshoot transactions in
complex distributed systems: collecting, storing, and visualising traces so you can follow a request as it flows across
services, find latency bottlenecks, and understand service dependencies. Jaeger was created by Uber Technologies and
donated to the Cloud Native Computing Foundation, where it is a graduated project. Jaeger v2 is a single unified binary
built as an OpenTelemetry Collector distribution; run with no arguments it starts in all-in-one mode with in-memory
storage, exposing the OTLP receivers, the collector, the query API, and the web UI from one process.

For more details, visit https://www.jaegertracing.io.

## Docker Hardened Images used

This image installs the pre-built `jaeger` binary from the Docker Hardened `dhi/pkg-jaeger` package and runs on the
Docker Hardened Debian 13 or Alpine 3.24 base. The runtime image ships only the `jaeger` binary, CA certificates, and
time zone data.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Jaeger is a trademark of The Linux Foundation. Jaeger is a graduated project of the Cloud Native Computing Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
