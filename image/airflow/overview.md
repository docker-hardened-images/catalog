## About Airflow

Apache Airflow is an open-source platform designed for developing, scheduling, and monitoring workflows. It allows you
to programmatically author, schedule, and monitor data pipelines using Python code. Airflow provides a rich user
interface for visualizing pipelines, monitoring progress, and troubleshooting issues when they arise.

With its extensible architecture, Airflow supports a wide variety of data sources and destinations through its provider
packages system. It offers robust scheduling capabilities, dependency management, and extensive logging and monitoring
features.

This Docker Hardened Airflow image is available in two variants:

- **Core variant**: A minimal runtime image equivalent to the upstream Apache Airflow "slim" tags, containing only the
  essential Airflow components without any provider packages
- **Dev variant**: A build-time image that includes all core functionality plus a shell and package manager, designed
  for installing providers and customizing Airflow installations
- **Compat variant**: A batteries-included image that includes all core functionality plus many popular airflow
  providers, designed as a drop-in replacement for upstream airflow images.

For more information about Apache Airflow, visit the upstream documentation at https://airflow.apache.org/docs/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
