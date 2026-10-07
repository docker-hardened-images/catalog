## About Harbor DB

Harbor DB is the PostgreSQL database component of the [Harbor](https://goharbor.io/) container registry — a
CNCF-graduated open-source project for storing, signing, and scanning container images. This image provides a drop-in
replacement for the upstream `goharbor/harbor-db` image, shipping Harbor-specific initialization, upgrade, and
healthcheck scripts with the PostgreSQL major versions selected by upstream Harbor. Harbor uses the database for
persistent storage of project metadata, user accounts, access policies, audit logs, and schema migrations.

Harbor 2.15 images include PostgreSQL 15 and 18. On first start, the entrypoint initializes PostgreSQL 18 and creates
the `registry` database with a `schema_migrations` table. When an existing PostgreSQL 15 data directory is detected, the
entrypoint automatically performs a `pg_upgrade` to PostgreSQL 18. Earlier supported Harbor lines retain their upstream
PostgreSQL 14-to-15 upgrade path.

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
