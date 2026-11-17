## About Stackdriver Exporter

Stackdriver Exporter exports Google Cloud Monitoring (formerly Stackdriver) metrics for Prometheus to scrape. It
requests time series from the Cloud Monitoring API for the metric prefixes you configure and exposes them on an HTTP
endpoint Prometheus can scrape.

Flag reference, filters, and metric naming are documented in the upstream project at
https://github.com/prometheus-community/stackdriver_exporter.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Prometheus® is a registered trademark of The Linux Foundation. Stackdriver™ and Google Cloud™ are trademarks of Google
LLC. All rights in the marks are reserved to their respective owners. Any use by Docker is for referential purposes only
and does not indicate sponsorship, endorsement, or affiliation.
