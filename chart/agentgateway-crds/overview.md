## About this Helm chart

This is an Agentgateway CRDs Helm chart built from the upstream Agentgateway CRDs Helm chart and using a hardened
configuration with Docker Hardened Images.

This chart installs the Gateway API and Agentgateway Custom Resource Definitions (CRDs) required by the Agentgateway
controller. Install this chart before installing the `agentgateway-chart`.

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://agentgateway.dev/docs/kubernetes/latest/quickstart/install/](https://agentgateway.dev/docs/kubernetes/latest/quickstart/install/)

## About Agentgateway

Agentgateway is an open-source, AI-first data plane hosted under the Linux Foundation. It provides HTTP/gRPC routing
alongside MCP, A2A, and LLM routing capabilities for AI agent deployments.

For more details, visit https://agentgateway.dev/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.
