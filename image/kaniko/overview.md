## About kaniko

kaniko builds container images from a Dockerfile inside a container or Kubernetes cluster, without a Docker daemon. It
runs each Dockerfile instruction in user space, snapshots the filesystem after each one, and pushes the result to a
registry, so it fits CI jobs and clusters that can't run a Docker daemon. This image packages the maintained,
Apache-2.0-licensed fork of the archived Google project, documented at https://github.com/chainguard-forks/kaniko.

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
