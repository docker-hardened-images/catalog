## About Milvus

[Milvus](https://milvus.io) is a high-performance, cloud-native vector database built for large-scale approximate
nearest neighbor (ANN) search over embedding vectors. It stores, indexes, and searches billions of vectors alongside
their metadata, and is a common building block for retrieval-augmented generation (RAG), semantic search, and
recommendation systems.

Milvus can run as a single self-contained `standalone` process — with an embedded etcd, local object storage, and an
embedded message queue — for development and small production workloads, or scale out into a distributed cluster backed
by an external etcd, S3-compatible object storage, and a Pulsar or Kafka message queue for larger deployments.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Milvus is a graduated project of the LF AI & Data Foundation. Milvus® is a registered trademark of LF Projects, LLC. All
rights in the mark are reserved to LF Projects, LLC. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.
