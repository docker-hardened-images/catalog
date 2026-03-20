## About KServe Storage Initializer

The KServe Storage Initializer is a utility component that runs as an init container in KServe deployments to download
model artifacts from various storage backends before the main model serving container starts.

It supports downloading models from:

- **Cloud Storage**: Amazon S3, Google Cloud Storage, Azure Blob Storage
- **Distributed Filesystems**: HDFS
- **Version Control**: Git repositories
- **Local Storage**: PVC, NFS, and other Kubernetes storage classes
- **Model Registries**: MLflow, and other registry systems

The storage initializer ensures that model files are available in the correct location before the inference server
starts, enabling seamless model deployment across different storage systems.

KServe is an incubation-stage project of the LF AI & Data Foundation that provides a Kubernetes Custom Resource
Definition for serving machine learning models with high abstraction interfaces for popular ML frameworks.

For more details, visit:

- https://kserve.github.io/website/latest/
- https://lfaidata.foundation/projects/kserve/

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
