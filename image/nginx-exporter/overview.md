## About Nginx Exporter

Nginx Exporter is an official Nginx tool that makes it possible to monitor Nginx and Nginx Plus with Prometheus by
exposing key metrics in Prometheus format. Developed and maintained by Nginx Inc., it provides a reliable way to collect
and export Nginx metrics for monitoring, alerting, and observability in cloud-native environments.

The exporter collects metrics from:

- **Nginx Open Source**: Basic connection and request metrics via the stub_status module
- **Nginx Plus**: Comprehensive metrics including upstream health, cache statistics, and detailed connection information
  via the Nginx Plus API
- **Nginx Ingress Controller**: Kubernetes-specific metrics when deployed as an ingress controller

Key metrics exposed include:

- **Connection metrics**: Active, accepted, handled connections, and connection states
- **Request metrics**: Total requests, requests per second, and request processing time
- **Upstream metrics** (Nginx Plus): Backend server health, response times, and load balancing statistics
- **Cache metrics** (Nginx Plus): Hit/miss ratios, cache size, and performance statistics
- **SSL/TLS metrics**: Certificate information and SSL handshake statistics
- **Zone metrics**: Per-location and per-server zone statistics

Key features include:

- **Simple deployment**: Single binary with minimal configuration requirements
- **Prometheus native**: Exports metrics in standard Prometheus exposition format
- **High performance**: Low overhead monitoring with efficient metric collection
- **Kubernetes ready**: Native support for Kubernetes deployments and service discovery
- **Secure**: Support for TLS/SSL connections to Nginx Plus API endpoints
- **Flexible configuration**: Configurable scrape intervals and metric filtering

Advanced capabilities:

- **Custom metric labels**: Add custom labels for better metric organization
- **Multiple Nginx instances**: Monitor multiple Nginx instances from a single exporter
- **Health checks**: Built-in health check endpoint for monitoring the exporter itself
- **Graceful shutdown**: Proper cleanup and shutdown procedures for container environments

For more details, visit https://github.com/nginx/nginx-prometheus-exporter.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
