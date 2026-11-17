## About Script Exporter

Script Exporter is a Prometheus exporter that runs the scripts you configure and turns their output or their exit status
into metrics. Prometheus scrapes `/probe?script=<name>`, the exporter runs that script with the query parameters as
arguments and environment, and reports the script's own metrics together with `script_success`,
`script_duration_seconds` and `script_exit_code`.

This hardened image is built from the official
[ricoberger/script_exporter](https://github.com/ricoberger/script_exporter) source and ships `bash`, `curl`, `jq`,
`python3` and `ping` for your scripts, as the upstream image does. The Alpine variants also keep upstream's BusyBox tool
set, so existing probe scripts run unchanged there; the Debian variants ship a smaller GNU tool set instead.

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
