## About Grafana Agent Operator

The Grafana Agent Operator is a Kubernetes operator that makes it easier to deploy the Grafana Agent and easier to
collect telemetry data from your pods. It is currently in beta, and is subject to change at any time.

It works by watching for Kubernetes custom resources that specify how you would like to collect telemetry data from your
Kubernetes cluster and where you would like to send it. They abstract Kubernetes-specific configuration that is more
tedious to perform manually. The Grafana Agent Operator manages corresponding Grafana Agent deployments in your cluster
by watching for changes against the custom resources.

> **Note**: Grafana Agent has been deprecated and is in Long-Term Support mode. Grafana recommends migrating to Grafana
> Alloy, the next-generation collector built on Grafana Agent Flow. Docker Hardened Images provides an
> [Alloy hardened image](https://hub.docker.com/r/grafana/alloy). For migration guidance, see the
> [Alloy migration documentation](https://grafana.com/docs/alloy/latest/tasks/migrate/).

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
