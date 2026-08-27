## About ClickHouse Keeper

ClickHouse Keeper is a coordination system for data replication and distributed DDL query execution in ClickHouse
clusters. It is a ZooKeeper-compatible replacement written in C++ that uses the RAFT consensus algorithm, providing
linearizable reads and writes.

ClickHouse Keeper can run as a standalone service or be embedded within ClickHouse Server. It maintains client-server
protocol compatibility with ZooKeeper, making it a drop-in replacement for existing deployments.

For more information and documentation see https://clickhouse.com/docs/guides/sre/keeper/clickhouse-keeper.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

ClickHouse is a trademark of ClickHouse, Inc. All rights in the mark are reserved to ClickHouse, Inc. Any use by Docker
is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
