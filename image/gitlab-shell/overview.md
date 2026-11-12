## About GitLab Shell

GitLab Shell handles Git operations over SSH for GitLab. This image runs `gitlab-sshd`, the standalone Go SSH server
used by Cloud Native GitLab (CNG) deployments: it terminates incoming SSH connections, authenticates the client's SSH
key or certificate against the GitLab internal API, and routes authorized Git operations to the rest of the GitLab
stack.

Unlike the OpenSSH-based mode, `gitlab-sshd` is a self-contained daemon that listens for SSH directly and exposes
Prometheus metrics and health endpoints over HTTP, making it well suited to Kubernetes and Docker Compose deployments
where GitLab services run as separate containers.

For more information, visit the [GitLab Shell documentation](https://docs.gitlab.com/development/gitlab_shell/).

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
