## About PgBouncer

PgBouncer is a lightweight connection pooler for PostgreSQL. It reduces the overhead of establishing new connections to
PostgreSQL by maintaining a pool of connections and reusing them across multiple client connections. PgBouncer is
particularly useful in high-concurrency environments where many clients need database access, as it dramatically reduces
connection overhead and improves overall database performance.

PgBouncer supports three pooling modes: session pooling, transaction pooling, and statement pooling, allowing you to
choose the appropriate level of connection sharing for your application. It also provides features like connection
limits, authentication, and query routing, making it an essential component for scaling PostgreSQL deployments.

For more information, visit https://www.pgbouncer.org/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

PostgreSQL® is a trademark of PostgreSQL Community Association of Canada. All rights in the mark are reserved to
PostgreSQL Community Association of Canada. Any use by Docker is for referential purposes only and does not indicate
sponsorship, endorsement, or affiliation. This listing is prepared by Docker. All third-party product names, logos, and
trademarks are the property of their
