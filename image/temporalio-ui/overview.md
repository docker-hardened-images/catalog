## Temporal Server

Temporal is a durable execution platform that enables developers to build scalable applications without sacrificing
productivity or reliability. The Temporal server executes units of application logic called Workflows in a resilient
manner that automatically handles intermittent failures, and retries failed operations.

### Key Features

- **Durable Execution**: Workflows survive process failures and continue from where they left off
- **Automatic Retries**: Built-in retry logic handles transient failures
- **Distributed Architecture**: Scalable microservices architecture
- **Multi-Language Support**: SDKs available for Go, Java, Python, TypeScript, and more
- **Observability**: Rich monitoring and debugging capabilities

### Core Components

This image provides the Temporal server with all essential components:

- **Frontend Service**: gRPC API for client interactions
- **History Service**: Manages workflow execution state
- **Matching Service**: Routes tasks to workers
- **Worker Service**: Internal background processing

### Database Support

Temporal server supports multiple database backends:

- **PostgreSQL** (recommended)
- **MySQL**
- **Cassandra**
- **SQLite** (development only)

### About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Temporal™ is a trademark of Temporal Technologies, Inc. All rights in the mark are reserved to Temporal Technologies,
Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
