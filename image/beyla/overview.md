## About Grafana Beyla

Grafana Beyla is an eBPF-based zero-code auto-instrumentation agent for application observability. It automatically
captures distributed traces and metrics for HTTP, HTTPS, HTTP/2, gRPC, SQL, Redis, and Kafka traffic from any
application — regardless of programming language — without requiring code changes, recompilation, or a language-specific
SDK. Beyla reads application traffic directly from the Linux kernel using eBPF probes and exports telemetry in
OpenTelemetry (OTLP) format or exposes it as Prometheus metrics, making it a natural fit for Grafana, Tempo, and Mimir.

Beyla is part of Grafana's open-source observability stack. It targets services running on Linux hosts or in Kubernetes
clusters and is particularly useful for instrumenting legacy applications or polyglot environments where per-language
agents are impractical.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Grafana® is a registered trademark of Grafana Labs. All rights in the mark are reserved to Grafana Labs. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
