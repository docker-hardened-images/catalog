## About DataHub Ingestion

DataHub is an open-source metadata platform for the modern data stack. The `datahub` CLI provided by this image extracts
metadata from data sources, BI tools, transformation tools, and data warehouses, then emits that metadata to a DataHub
backend through ingestion recipes. It is commonly run as a scheduled job (Airflow, Prefect, cron, Kubernetes CronJob) to
keep the DataHub catalog in sync with upstream systems.

This Docker Hardened DataHub Ingestion image is available in two variants matching the upstream
`acryldata/datahub-ingestion` layout:

- **Slim variant** (default): Minimal install with the most commonly used ingestion connectors (Snowflake, BigQuery,
  Redshift, MySQL, PostgreSQL, S3, GCS, Azure Blob Storage, ClickHouse, Glue, dbt, Looker, LookML, Tableau, Power BI,
  Superset, Kafka, Business Glossary). Suitable for the majority of ingestion deployments.
- **Locked variant** (`-locked`): Hardened airgap variant. Network access to PyPI is blocked at runtime via
  `UV_INDEX_URL` and `PIP_INDEX_URL` pointed at an unreachable endpoint, so the image can only run with the connectors
  baked in at build time. Useful for regulated environments that prohibit unaudited runtime package installation.

For more information about DataHub, visit the upstream documentation at https://docs.datahub.com/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Oracle® is a registered trademark of Oracle Corporation and/or its affiliates; Oracle Instant Client is a product of
Oracle Corporation. All other third-party product names, logos, and trademarks are the property of their respective
owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
