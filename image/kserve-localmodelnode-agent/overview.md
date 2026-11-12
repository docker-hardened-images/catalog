## About KServe LocalModelNode Agent

The KServe LocalModelNode Agent is a Kubernetes controller component that manages local model node operations within a
KServe deployment. It enables efficient node-level model management by handling the lifecycle of machine learning models
on individual nodes, providing fine-grained control over model distribution and caching across the cluster.

The LocalModelNode Agent provides:

- **Node-Level Model Management**: Manage models at the node level for optimized resource utilization
- **Local Storage Coordination**: Coordinate local storage across nodes for model artifacts
- **Model Distribution**: Handle efficient model distribution and caching on individual nodes
- **Integration with KServe**: Works seamlessly with other KServe components like the LocalModel controller and storage
  initializer

This controller is typically deployed as part of a complete KServe installation and runs as a Kubernetes controller,
monitoring and managing local model node resources to optimize model serving performance and resource utilization across
the cluster.

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
