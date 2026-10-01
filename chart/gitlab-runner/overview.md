## About this Helm chart

This is a GitLab Runner Docker Hardened Helm chart built from the upstream GitLab Runner Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/gitlab-runner`
- `dhi/gitlab-runner-helper`
- `dhi/busybox`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://docs.gitlab.com/runner/install/kubernetes.html](https://docs.gitlab.com/runner/install/kubernetes.html)

### About GitLab Runner

GitLab Runner is the open source application that runs GitLab CI/CD jobs and sends the results back to GitLab. This
chart deploys the runner manager on Kubernetes using the Kubernetes executor, which starts a new pod for each CI/CD job.

For more information and documentation see https://docs.gitlab.com/runner/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

GitLab® is a registered trademark of GitLab Inc. All rights in the mark are reserved to GitLab Inc. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
