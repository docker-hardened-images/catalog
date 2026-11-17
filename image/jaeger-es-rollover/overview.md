## About Jaeger ES Rollover

[Jaeger](https://www.jaegertracing.io/) is an open-source, end-to-end distributed tracing platform used to monitor and
troubleshoot transactions in complex microservice architectures. When Jaeger stores spans in Elasticsearch it can write
through read and write aliases instead of one index per day, so that indices roll over by age, size or document count.
This image ships the Jaeger `es-rollover` tool, which prepares Elasticsearch for that mode and keeps it running: `init`
creates the index templates, the first numbered index and the aliases; `rollover` moves the write alias to a new index
when the configured conditions are met; `lookback` drops indices older than a window from the read alias. Each
subcommand runs to completion and exits, so `init` is run once and the other two are scheduled as recurring jobs.

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
