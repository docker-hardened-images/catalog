## About this Helm chart

This is Promtail Docker Hardened Helm chart built from the upstream Promtail Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/promtail`
- `dhi/prometheus-config-reloader`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/grafana/helm-charts/tree/main/charts/promtail](https://github.com/grafana/helm-charts/tree/main/charts/promtail)

## About Promtail

Promtail is an agent which ships the contents of local logs to a private Grafana Loki instance or Grafana Cloud. It is
usually deployed to every machine that runs applications which need to be monitored.

It primarily:

- Discovers targets
- Attaches labels to log streams
- Pushes them to the Loki instance.

For more details, visit https://grafana.com/docs/loki/latest/send-data/promtail/.

Note that Promtail is in EOL phase, with LTS lasting until February 2026. This will include bug and security fixes, but
nothing else.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Grafana® Pomtail is a trademark of Raintank, Inc. dba Grafana Labs. All rights in the mark are reserved to Raintank,
Inc. dba Grafana Labs. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
