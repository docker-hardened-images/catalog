## About this Helm chart

This is an Envoy AI Gateway CRDs Helm chart built from the upstream `ai-gateway-crds-helm` chart and using a hardened
configuration with Docker Hardened Images.

This chart installs the Envoy AI Gateway Custom Resource Definitions (CRDs) required by the Envoy AI Gateway
controller. Install this chart before installing the `envoy-ai-gateway-chart`.

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://aigateway.envoyproxy.io/docs/](https://aigateway.envoyproxy.io/docs/)

## About Envoy AI Gateway

Envoy AI Gateway is an open-source project that provides a unified, provider-agnostic, OpenAI-compatible API for
routing to LLM providers (AWS Bedrock, OpenAI, Anthropic, Azure OpenAI, and more). It is built on top of Envoy Gateway.

For more details, visit https://aigateway.envoyproxy.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.
