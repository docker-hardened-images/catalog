## About GitLab Workhorse

GitLab Workhorse is a smart reverse proxy that sits in front of the GitLab Rails application. It handles
resource-intensive HTTP requests that would otherwise tie up Rails workers — file uploads and downloads, Git operations
over HTTP, and repository archive downloads — and streams them efficiently to and from object storage and Gitaly.

This is the Cloud Native GitLab (CNG) workhorse component, designed for Kubernetes and Docker Compose deployments where
GitLab services run as separate containers. It is normally deployed alongside the GitLab Webservice (Puma) container,
which it proxies via its configured authentication backend.

Like the upstream image, this image bundles the version-matched compiled GitLab Rails assets under `/srv/gitlab/public`,
allowing Workhorse to serve the web UI's CSS, JavaScript, fonts, and images directly. The upstream `/srv/gitlab/doc`
content is intentionally omitted because Workhorse does not require it.

For more information, visit the [GitLab Workhorse documentation](https://docs.gitlab.com/development/workhorse/).

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
