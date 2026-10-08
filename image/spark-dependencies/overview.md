## About Jaeger Spark Dependencies

Jaeger is a CNCF graduated, open-source distributed tracing platform originally created by Uber Technologies. Jaeger
Spark Dependencies is an Apache Spark batch job that analyzes spans stored in a Jaeger backend to compute service
dependency links — which services call which — for display in the Jaeger UI's dependency graph. It runs once per day (or
on demand for a specific date) rather than as a long-running service, and is only needed for Jaeger's production
deployment model; the `all-in-one` distribution does not require it.

This image ships a separate build for each supported storage backend — Cassandra, Elasticsearch (7.x, 8.x, and 9.x), and
OpenSearch — selected via the image tag/flavor, since each backend requires a different storage-connector version
compiled into the job's jar. For full documentation, see the
[Jaeger project documentation](https://www.jaegertracing.io/docs/).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Jaeger® is a trademark of The Linux Foundation. All rights in the mark are reserved to The Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation. Apache Spark and
Spark are trademarks of the Apache Software Foundation.
