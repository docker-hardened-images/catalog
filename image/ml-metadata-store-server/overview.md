## About ML Metadata Store Server

ML Metadata (MLMD) is a library for recording and retrieving metadata about machine learning workflows: the datasets,
models, and other artifacts a pipeline produces, the executions that produce them, and the lineage between them. It is
part of TensorFlow Extended (TFX), and Kubeflow Pipelines runs it as its metadata gRPC service.

This image packages `metadata_store_server`, the gRPC server that exposes the MLMD API to remote clients and stores
metadata in MySQL, PostgreSQL, or SQLite. For the full documentation, visit https://github.com/google/ml-metadata.

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
