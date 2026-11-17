## About Azure Metrics Exporter

Azure Metrics Exporter is a Prometheus exporter that collects metrics from Azure Monitor and exposes them in Prometheus
format. It provides comprehensive monitoring capabilities for Azure resources by bridging the gap between Azure's native
monitoring service and Prometheus-based observability stacks.

The exporter supports multiple Azure environments and provides dimension support for detailed metric analysis. It
includes a template engine for customizable metric naming, service discovery capabilities to automatically discover
Azure resources, and caching mechanisms to reduce API calls and improve performance.

Built with efficiency in mind, Azure Metrics Exporter runs as a lightweight binary that can be deployed in various
environments including Kubernetes clusters. It supports multiple Azure authentication methods and provides detailed
configuration options for fine-tuning metric collection according to specific monitoring requirements.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Microsoft® and Azure® are trademarks of Microsoft Corporation. All rights in these marks are reserved to Microsoft
Corporation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
