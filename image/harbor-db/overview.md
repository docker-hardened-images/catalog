## About Harbor DB

Harbor DB is the PostgreSQL database component of the [Harbor](https://goharbor.io/) container registry — a
CNCF-graduated open-source project for storing, signing, and scanning container images. This image provides a drop-in
replacement for the upstream `goharbor/harbor-db` image, shipping Harbor-specific initialization, upgrade, and
healthcheck scripts on top of PostgreSQL 14 and 15. Harbor uses the database for persistent storage of project metadata,
user accounts, access policies, audit logs, and schema migrations.

This image includes both PostgreSQL 14 and 15 to support in-place database upgrades from older Harbor releases. On first
start, the entrypoint initializes a fresh PostgreSQL 15 cluster and creates the `registry` database with a
`schema_migrations` table. When an existing PostgreSQL 14 data directory is detected, the entrypoint automatically
performs a `pg_upgrade` to PostgreSQL 15.

This image is purpose-built for Harbor deployments and is not a general-purpose PostgreSQL image. It is designed to be
used as a component within a full Harbor installation, whether deployed via Docker Compose or Kubernetes.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Harbor™ is a trademark of the Cloud Native Computing Foundation (CNCF). PostgreSQL® is a registered trademark of the
PostgreSQL Community Association of Canada.
