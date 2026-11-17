## About Linkerd Proxy

[Linkerd](https://linkerd.io) is a CNCF service mesh for Kubernetes. The Linkerd proxy is the Rust data plane that
Linkerd injects as a sidecar next to every meshed workload, giving it mutual TLS, load balancing, retries and metrics
without application changes.

This image is the `linkerd-proxy` container Linkerd injects into meshed pods. It also carries the
`linkerd2-network-validator` and `linkerd2-proxy-init` tools used by the init container.

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
