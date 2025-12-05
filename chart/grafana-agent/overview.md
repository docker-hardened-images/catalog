## About this Helm chart

This is a Grafana Agent Docker Hardened Helm chart built from the upstream Grafana Agent Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/grafana-agent`
- `dhi/configmap-reload`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/grafana/agent/blob/main/operations/helm/charts/grafana-agent/README.md](https://github.com/grafana/agent/blob/main/operations/helm/charts/grafana-agent/README.md)

## About Grafana Agent

Grafana Agent is a lightweight, unified telemetry collector from Grafana Labs. It gathers metrics, logs, traces, and
continuous profiles from infrastructure and applications, serving as a single replacement for multiple specialized
collectors. It integrates with Prometheus for metrics, Loki for logs, Tempo for distributed tracing, and Pyroscope for
profiling, making it a flexible and comprehensive observability solution.

The agent is well suited for Kubernetes deployments, often running as a DaemonSet to collect telemetry from pods and
system components. It can scrape Prometheus metrics, tail log files, receive traces via common protocols, and gather
profiling data, forwarding everything to backends like Prometheus, Grafana Cloud, or other compatible systems. Its
efficient, low-resource design makes it particularly effective in edge or resource-constrained environments where
running multiple collectors would be impractical.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Grafana® is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank, Inc. dba
Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
