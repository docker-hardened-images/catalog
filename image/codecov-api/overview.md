## About Codecov API

Codecov API is the Django backend of a self-hosted [Codecov](https://about.codecov.io/) deployment. It serves the REST
and GraphQL APIs behind the Codecov dashboard, receives coverage uploads and repository webhooks from GitHub, GitLab and
Bitbucket, and applies the database migrations for a Codecov instance on startup. It ships from the
[codecov/umbrella](https://github.com/codecov/umbrella) monorepo alongside the Codecov worker and runs next to
PostgreSQL, TimescaleDB, Redis and an S3-compatible object store.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Codecov is a trademark of Harness, Inc. All rights in the mark are reserved to Harness, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
