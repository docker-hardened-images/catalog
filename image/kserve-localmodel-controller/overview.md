## About KServe LocalModel Controller

The KServe LocalModel Controller is a Kubernetes controller component that manages local model caching and storage
within a KServe deployment. It enables efficient model management by handling the caching of machine learning models on
local storage, reducing the need to repeatedly download models from remote storage backends.

The LocalModel controller provides:

- **Local Model Caching**: Cache frequently-used models locally to improve inference startup times
- **Storage Management**: Efficiently manage local storage resources for model artifacts
- **Model Lifecycle**: Handle model loading, caching, and cleanup operations
- **Integration with KServe**: Works seamlessly with other KServe components like the storage initializer and inference
  services

This controller is typically deployed as part of a complete KServe installation and runs as a Kubernetes controller,
monitoring and managing local model resources across the cluster to optimize model serving performance and resource
utilization.

For more details, visit:

- https://kserve.github.io/website/

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
