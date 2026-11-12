## About GitLab Pages

GitLab Pages is the static site hosting service built into GitLab, similar to GitHub Pages. It serves static websites
directly out of a GitLab project repository, with support for custom domains, CNAMEs, SNI-based TLS, GitLab access
control, and PROXY protocol for load balancers.

This is the Cloud Native GitLab (CNG) Pages component, designed for Kubernetes and Docker Compose deployments where
GitLab services run as separate containers. It requires a running GitLab instance to resolve project and domain
configuration via the GitLab API.

For more information, visit the [official GitLab Pages documentation](https://docs.gitlab.com/ee/administration/pages/).

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
