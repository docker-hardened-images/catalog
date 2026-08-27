## About this Helm chart

This is an Envoy Gateway Helm chart built from the upstream Envoy Gateway Helm chart and using a hardened configuration
with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/envoy-gateway`
- `dhi/envoy-ratelimit`
- `dhi/envoy`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/envoyproxy/gateway/tree/v1.7.0/charts/gateway-helm/README.md](https://github.com/envoyproxy/gateway/tree/v1.7.0/charts/gateway-helm/README.md)

## About Envoy Gateway

Envoy Gateway is an open source project for managing Envoy Proxy as a standalone or Kubernetes-based application
gateway. It implements and extends the Kubernetes Gateway API, providing a simplified, Kubernetes-native way to
configure routing rules, security policies, and traffic management without requiring low-level Envoy configuration.

Envoy Gateway provides features such as traffic routing, load balancing, TLS termination, rate limiting, authentication
(including OAuth2 and OIDC), and observability. It is designed to make it easier for organizations to leverage the
high-performance Envoy Proxy for managing north-south API traffic.

For more details, visit https://gateway.envoyproxy.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Envoy® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
