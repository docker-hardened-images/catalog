## About Beat Exporter

beat-exporter is a Prometheus exporter for [Elastic Beats](https://www.elastic.co/beats/) (Filebeat, Metricbeat,
Packetbeat, Auditbeat, and others). It scrapes the Beat HTTP monitoring endpoint (default `http://localhost:5066`) and
exposes the collected metrics in Prometheus format on port `9479`, making Beat operational data available for alerting
and dashboards in Prometheus-based observability stacks. Upstream releases have been infrequent since version 0.4.0 in
June 2020.

For more information on beat-exporter, see the [upstream project](https://github.com/trustpilot/beat-exporter).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Beats®, Elasticsearch®, Filebeat®, Metricbeat®, Packetbeat®, and Auditbeat® are registered trademarks of Elastic NV. All
rights in those marks are reserved to Elastic NV. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.

beat-exporter is an open source project by Trustpilot A/S, distributed under the MIT License. Any use of the Trustpilot
name is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
