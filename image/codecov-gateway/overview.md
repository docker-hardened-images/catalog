## About Codecov Gateway

Codecov Gateway is the entry point of a self-hosted [Codecov](https://about.codecov.io/) deployment: an HAProxy reverse
proxy that receives every request for the deployment and routes it by path to the Codecov API, the internal API, the
frontend and, when enabled, the MinIO object store, the way Ambassador does for the hosted service. It is configured
through environment variables, waits for its backends before it starts serving, and terminates TLS when a certificate is
mounted.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Codecov is a trademark of Harness, Inc. All rights in the mark are reserved to Harness, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
