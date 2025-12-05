## About this Helm chart

This is an Alertmanager Docker Hardened Helm chart built from the official upstream Alertmanager chart and using a
hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/alertmanager`
- `dhi/prometheus-config-reloader`
- `dhi/busybox`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/prometheus-community/helm-charts](https://github.com/prometheus-community/helm-charts)

### About Alertmanager

Prometheus Alertmanager receives alerts from Prometheus servers, deduplicates and groups them, and routes notifications
to configured receivers such as email, Slack, PagerDuty, or webhooks. It supports silencing, inhibition, and
high-availability clustering to ensure reliable delivery of notifications in production environments.

Official documentation: https://prometheus.io/docs/alerting/latest/alertmanager/

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
