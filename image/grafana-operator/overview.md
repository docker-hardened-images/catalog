## About Grafana Operator

[Grafana Operator](https://github.com/grafana/grafana-operator) is a Kubernetes operator that automates the management
of Grafana instances, dashboards, datasources, and other Grafana resources using custom resources (CRs).

Key features include:

- **Declarative Grafana management**: Define Grafana instances as Kubernetes custom resources
- **Dashboard automation**: Manage dashboards as code with GrafanaDashboard CRs
- **Datasource management**: Configure datasources declaratively with GrafanaDatasource CRs
- **Multi-instance support**: Manage multiple Grafana instances across namespaces
- **GitOps ready**: Integrates seamlessly with ArgoCD, Flux, and other GitOps tools

Advanced capabilities:

- Automatic synchronization of dashboards and datasources
- Support for dashboard discovery via label selectors
- External dashboard sources (Grafana.com, URLs, ConfigMaps)
- Alert rule and notification management
- Plugin management

## About Docker Hardened Images

Docker Hardened Images (DHI) are secure, minimal container images with near-zero CVEs, signed provenance, and complete
SBOM/VEX metadata. They provide a secure foundation for production workloads.

## Trademarks

Grafana® is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank, Inc. dba
Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
