## About this Helm chart

This is a Grafana Agent Operator Docker Hardened Helm chart built from the upstream Grafana Agent Operator Helm chart
and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/grafana-agent-operator`
- `dhi/busybox`
- `dhi/grafana-agent`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/grafana/helm-charts/blob/main/charts/agent-operator/README.md](https://github.com/grafana/helm-charts/blob/main/charts/agent-operator/README.md)

## About Grafana Agent Operator

This image contains Grafana Agent Operator, a Kubernetes operator built to help you manage your Grafana instances and
its resources in and outside of Kubernetes. You can still run it with the Docker cli to get help about the different
configuration options.

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
