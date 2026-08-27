## About KServe Router

The KServe Router is a component that orchestrates inference requests across multiple models in a KServe deployment. It
routes requests based on an inference graph definition, enabling complex model serving patterns for machine learning
inference pipelines.

The router supports:

- **Sequential routing**: Chain models together for preprocessing, inference, and postprocessing workflows
- **Conditional routing**: Route requests to different models based on conditions or request content
- **Parallel execution**: Send requests to multiple models simultaneously and aggregate results
- **Ensemble serving**: Combine outputs from multiple models for improved predictions

The router integrates with KServe's InferenceGraph custom resource and automatically handles request routing based on
the configured graph topology, making it simple to deploy sophisticated multi-model inference workflows in Kubernetes.

For more details, visit:

- https://kserve.github.io/website/latest/

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
