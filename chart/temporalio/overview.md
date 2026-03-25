## About this Helm chart

This is a Temporal Docker Hardened Helm chart built from the upstream Temporal Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Helm charts are used in this Helm chart:

- `dhi/prometheus-chart`
- `dhi/grafana-chart`

The following Docker Hardened Images are used in this Helm chart:

- `dhi/temporal-server`
- `dhi/temporal-admin-tools`
- `dhi/temporal-ui`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/temporalio/helm-charts/blob/main/README.md](https://github.com/temporalio/helm-charts/blob/main/README.md)

## About Temporal

Temporal is a durable execution platform that enables developers to build scalable applications without sacrificing
productivity or reliability. The Temporal server executes units of application logic called Workflows in a resilient
manner that automatically handles intermittent failures, and retries failed operations.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Temporal™ is a trademark of Temporal Technologies, Inc. All rights in the mark are reserved to Temporal Technologies,
Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
