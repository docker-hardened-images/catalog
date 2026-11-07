## About this Helm chart

This is a KGateway Helm chart built from the upstream KGateway Helm chart and using a hardened configuration
with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/kgateway`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://kgateway.dev/docs/](https://kgateway.dev/docs/)

## About KGateway

KGateway (formerly Gloo Gateway OSS) is a Kubernetes-native gateway that implements the Kubernetes Gateway API. It uses
Envoy Proxy as its data plane and is maintained by Solo.io. KGateway provides advanced traffic management, AI gateway
capabilities, and a simplified Kubernetes-native way to configure routing rules, security policies, and traffic
management.

For more details, visit https://kgateway.dev/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.
