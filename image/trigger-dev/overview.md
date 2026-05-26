## About Trigger.dev

Trigger.dev is an open-source background jobs and AI workflow platform for TypeScript. It lets developers write
long-running, durable workflows ("tasks") in regular TypeScript code and run them on infrastructure that handles
queueing, retries, scheduling, real-time progress, and observability without the operational burden of building a job
runner from scratch.

This image packages the self-hosted `trigger.dev` webapp (the API server, scheduler, and dashboard) so teams can run the
platform inside their own VPC alongside Postgres, Redis, and (optionally) ClickHouse. Use it for self-hosting the entire
platform, isolating workloads on private infrastructure, or meeting compliance requirements that preclude the hosted
Trigger.dev Cloud offering. See the official documentation at https://trigger.dev/docs for full configuration reference
and deployment topologies.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

trigger.dev is a registered trademark of Trigger.dev Inc. All rights in the mark are reserved to Trigger.dev Inc. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
