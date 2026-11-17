## About Azure ResourceGraph Exporter

Azure ResourceGraph Exporter is a Prometheus exporter that runs Azure Resource Graph queries and exposes the results as
Prometheus metrics. It lets you build custom inventory and compliance metrics (resource counts, tags, configuration
attributes) from Azure Resource Graph without writing a bespoke collector.

Queries and their metric fields are defined in a configuration file, so the same exporter binary can serve many
different metrics depending on how it's configured. The exporter also supports caching query results and exposes tracing
metrics for the underlying Azure API calls.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Microsoft® and Azure® are trademarks of Microsoft Corporation. All rights in these marks are reserved to Microsoft
Corporation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
