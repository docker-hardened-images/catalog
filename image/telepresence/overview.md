## About Telepresence

Telepresence is a Cloud Native Computing Foundation (CNCF) project that connects a developer workstation to a remote
Kubernetes cluster. You can run and debug one service locally with your own tools while it receives real traffic from
the cluster, without a container build, push, and deploy cycle. The project is published at https://telepresence.io.

This Docker Hardened Image is the Telepresence client image. The `telepresence connect --docker` command starts it as
the daemon container on the host, and it also runs the `telepresence` CLI. It is the hardened stand-in for the upstream
image `ghcr.io/telepresenceio/telepresence`. It does not contain the cluster-side traffic manager or traffic agent.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Telepresence™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a registered trademark of The Linux Foundation. Any use by Docker is for referential purposes only and
does not indicate sponsorship, endorsement, or affiliation.
