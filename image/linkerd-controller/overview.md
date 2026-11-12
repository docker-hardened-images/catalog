## About Linkerd Controller

[Linkerd](https://linkerd.io) is a CNCF service mesh for Kubernetes. The Linkerd controller image runs the control plane
components that configure the mesh: `destination` serves service discovery and routing information to the proxies,
`identity` issues their mutual TLS certificates, `proxy-injector` adds the proxy to pods, `sp-validator` validates
service profiles, `heartbeat` reports anonymous version checks, and `service-mirror` mirrors services between clusters
for the Linkerd multicluster extension. The same image carries the policy controller that serves inbound authorization
policy to the proxies and keeps the policy resource status up to date.

This image is the `controller` container the Linkerd Helm chart runs for the `linkerd-destination`, `linkerd-identity`
and `linkerd-proxy-injector` deployments and for the `linkerd-heartbeat` job.

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
