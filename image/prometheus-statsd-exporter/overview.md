## About StatsD Exporter

StatsD Exporter is a Prometheus exporter that receives StatsD-style metrics and exports them as Prometheus metrics. It
acts as a bridge between applications that emit StatsD metrics and Prometheus monitoring systems.

StatsD Exporter supports multiple tagging formats including Librato, InfluxDB, DogStatsD, and SignalFX. It allows
flexible metric name and label transformations through configurable mapping rules, enabling you to convert StatsD
metrics into meaningful Prometheus metrics with proper labels and naming conventions.

The exporter can handle various StatsD metric types including counters, gauges, timers, histograms, and sets. It
provides configuration options for timer and distribution metric handling, and can drop or explicitly map specific
metric types based on your needs.

For more details, visit https://github.com/prometheus/statsd_exporter.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Prometheus® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
