## About pgvector

pgvector is an open-source vector similarity search extension for PostgreSQL. It adds a `vector` data type along with
exact and approximate nearest neighbor search, allowing PostgreSQL databases to store and query embeddings produced by
machine learning models. pgvector supports L2 distance, inner product, cosine distance, L1 distance, Hamming distance,
and Jaccard distance, with HNSW and IVFFlat indexes for fast approximate search at scale.

This image bundles pgvector with a Docker Hardened PostgreSQL base, providing a turnkey vector database for retrieval
augmented generation (RAG), semantic search, recommendation systems, and similarity workloads.

For more information, visit https://github.com/pgvector/pgvector.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

PostgreSQL® is a trademark of PostgreSQL Community Association of Canada. All rights in the mark are reserved to
PostgreSQL Community Association of Canada. Any use by Docker is for referential purposes only and does not indicate
sponsorship, endorsement, or affiliation.

pgvector is open-source software distributed under the PostgreSQL License. Use by Docker is for referential purposes
only and does not indicate sponsorship, endorsement, or affiliation.
