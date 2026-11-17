## About GitLab Sidekiq

GitLab Sidekiq runs the background job processor for the GitLab Rails application. It handles asynchronous work such as
email delivery, repository imports and mirroring, CI/CD pipeline processing, and other tasks that run outside the web
request cycle.

This is the Cloud Native GitLab (CNG) Sidekiq component, designed for Kubernetes and Docker Compose deployments where
GitLab services run as separate containers. It runs on top of the full GitLab Rails application and requires external
PostgreSQL, Redis, and Gitaly services to operate.

For more information, visit the [official GitLab documentation](https://docs.gitlab.com/).

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
