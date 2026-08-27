## About GitLab Webservice

GitLab Webservice runs the Puma application server for the GitLab Rails application. It provides the web UI and API
endpoints for GitLab, handling HTTP requests for project management, CI/CD pipelines, merge requests, and all other
GitLab web functionality.

This is the Cloud Native GitLab (CNG) webservice component, designed for Kubernetes and Docker Compose deployments where
GitLab services run as separate containers. It requires external PostgreSQL, Redis, and Gitaly services to operate.

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
