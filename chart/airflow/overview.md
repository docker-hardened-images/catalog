## About this Helm chart

This is an Apache Airflow Docker Hardened Helm chart built from the upstream Apache Airflow Helm chart and using a
hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/airflow`
- `dhi/prometheus-statsd-exporter`
- `dhi/pgbouncer`
- `dhi/git-sync`
- `dhi/redis`
- `dhi/opentelemetry-collector`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://airflow.apache.org/docs/helm-chart/stable/index.html](https://airflow.apache.org/docs/helm-chart/stable/index.html)

## About Apache Airflow

Apache Airflow is an open-source platform to programmatically author, schedule, and monitor workflows. It allows you to
define complex data pipelines as directed acyclic graphs (DAGs) of tasks written in Python. Airflow's rich UI makes it
easy to visualize pipelines running in production, monitor progress, and troubleshoot issues when needed.

Airflow supports a wide range of integrations including AWS, GCP, Azure, Kubernetes, and hundreds of community
providers, making it a versatile tool for orchestrating ETL pipelines, machine learning workflows, and data engineering
tasks.

For more details, visit https://airflow.apache.org/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Apache Airflow® is a registered trademark of the Apache Software Foundation. All rights in the mark are reserved to the
Apache Software Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
