## About Linkerd Web

[Linkerd](https://linkerd.io) is a CNCF service mesh for Kubernetes. Linkerd web is the viz dashboard: it serves the UI
for traffic, topology, and the health of meshed workloads, using metrics from the Linkerd metrics API.

This image contains the dashboard binary and static assets, and the Linkerd viz Helm chart runs it as the dashboard
container. Project documentation is the [Linkerd overview](https://linkerd.io/2/overview/) and the
[getting started guide](https://linkerd.io/2/getting-started/).

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
