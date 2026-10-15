## About this Helm chart

This is an Envoy AI Gateway Helm chart built from the upstream `ai-gateway-helm` chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/envoy-ai-gateway-controller`
- `dhi/envoy-ai-gateway-extproc`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://aigateway.envoyproxy.io/docs/](https://aigateway.envoyproxy.io/docs/)

## About Envoy AI Gateway

Envoy AI Gateway provides a unified, provider-agnostic, OpenAI-compatible API for routing to LLM providers such as
AWS Bedrock, OpenAI, Anthropic, and Azure OpenAI. Built on top of Envoy Gateway, it adds token-based rate limiting,
upstream authentication, and per-route observability for AI/LLM traffic.

For more details, visit https://aigateway.envoyproxy.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.
