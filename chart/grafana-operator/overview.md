## About this Helm chart

This is a Grafana Operator Helm chart built from the upstream Grafana Operator Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/grafana-operator`

## About Grafana Operator

[Grafana Operator](https://github.com/grafana/grafana-operator) is a Kubernetes operator that automates the management
of Grafana instances, dashboards, datasources, and other Grafana resources using custom resources (CRs).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Grafana® is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank, Inc. dba
Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
