## About Jaeger Ingester

[Jaeger](https://www.jaegertracing.io/) is an open-source, end-to-end distributed tracing platform used to monitor and
troubleshoot transactions in complex microservice architectures. In Jaeger v2, the separate per-component binaries from
v1 (collector, query, ingester) were unified into a single OpenTelemetry Collector-based `jaeger` binary. This image
ships that unified binary preconfigured to run in Kafka-ingester mode: it consumes spans from a Kafka topic and writes
them to a configured storage backend, fulfilling the role of the storage-side consumer in a
`jaeger-collector → Kafka → jaeger-ingester → storage` pipeline.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Jaeger is a trademark of The Linux Foundation. All rights in the mark are reserved to The Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
