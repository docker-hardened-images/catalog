## About GitLab Exporter

GitLab Exporter is a Prometheus exporter that gathers metrics from a running GitLab deployment. It opens read
connections to the deployment's PostgreSQL database, Redis/Sidekiq queues, and Git processes, and exposes the results
over HTTP for Prometheus to scrape.

This is the Cloud Native GitLab (CNG) exporter component, designed for Kubernetes and Docker Compose deployments where
GitLab services run as separate containers. It runs as a long-lived HTTP server on port 9168 and is polled by a central
Prometheus; database and Sidekiq probes require access to the GitLab deployment's PostgreSQL and Redis instances.

For more information, visit the
[official GitLab documentation](https://docs.gitlab.com/ee/administration/monitoring/prometheus/gitlab_exporter.html).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

GitLab is a trademark of GitLab Inc. in the United States and other countries and regions. All rights in the mark are
reserved to GitLab Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
