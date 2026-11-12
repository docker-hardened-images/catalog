## About Langfuse Worker

Langfuse Worker is the background job processor for the Langfuse open-source LLM engineering platform. It handles
asynchronous workloads that the web application offloads — including LLM evaluation jobs, trace ingestion pipelines,
batch exports, data retention enforcement, and external integration queues — over a Redis-backed BullMQ job queue. It is
always deployed alongside the `langfuse` web image and shares the same PostgreSQL and ClickHouse databases; it exposes
no user-facing UI or public API beyond its internal health and readiness endpoints.

For more information about Langfuse, visit <https://langfuse.com>.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Langfuse™ is a trademark of Langfuse GmbH. All rights in the mark are reserved to Langfuse GmbH. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
