## About Envoy Rate Limit Service

Envoy Rate Limit Service (ratelimit) is a Go-based gRPC service that provides centralized rate limiting for Envoy and
other proxies. It evaluates rate limit descriptors against configured limits (in files, xDS, or via runtime) and uses
Redis or Memcache backends to store counters and enforce limits.

The service is commonly used to implement global or per-user rate limiting for APIs and microservices, integrate with
Envoy's rate limit filter, and expose a /json REST endpoint for testing and a debug/metrics port for observability. For
full configuration details and examples, see the upstream project: https://github.com/envoyproxy/ratelimit

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Envoy® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
