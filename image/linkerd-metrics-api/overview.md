## About Linkerd Metrics API

[Linkerd](https://linkerd.io) is a CNCF service mesh for Kubernetes. The Linkerd metrics API is part of the Linkerd viz
extension. It combines the traffic metrics Prometheus scrapes from the Linkerd proxies with resource information from
the Kubernetes API, and answers the stat summary, top routes, edges and gateways queries that the Linkerd dashboard and
the `linkerd viz` CLI commands send.

This image is the `metrics-api` container the Linkerd viz Helm chart runs in the `metrics-api` deployment.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Linkerd® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
