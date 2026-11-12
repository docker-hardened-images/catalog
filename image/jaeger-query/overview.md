## About Jaeger Query

Jaeger is a CNCF graduated, open-source distributed tracing platform originally created by Uber Technologies. It enables
end-to-end transaction monitoring across microservices by collecting, storing, and visualizing trace data. Jaeger v2 is
a unified binary built on the OpenTelemetry Collector framework — the query service, collector, and all-in-one modes are
all served by the same `jaeger` binary, selected entirely by the configuration file passed at startup.

This image runs the Jaeger binary in **query-service mode**, which serves the Jaeger UI (an embedded React web interface
for browsing and analyzing traces) and exposes the query HTTP and gRPC APIs for retrieving traces from a configurable
storage backend. Supported backends include Elasticsearch, OpenSearch, Cassandra, ClickHouse, Badger, and remote-storage
gRPC services. For full documentation, see the [Jaeger project documentation](https://www.jaegertracing.io/docs/).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Jaeger® is a trademark of The Linux Foundation. All rights in the mark are reserved to The Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
