## About Jaeger ES Index Cleaner

[Jaeger](https://www.jaegertracing.io/) is an open-source, end-to-end distributed tracing platform used to monitor and
troubleshoot transactions in complex microservice architectures. When Jaeger stores spans in Elasticsearch it writes a
new set of indices per day, and those indices accumulate until something removes them. This image ships the Jaeger
`es-index-cleaner` tool, which deletes Jaeger indices older than a given number of days from an Elasticsearch cluster.
It runs to completion and exits, so it is normally scheduled as a recurring job rather than run as a long-lived service.

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
