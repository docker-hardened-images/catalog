## About Hubble UI Backend

Hubble UI Backend is a component of the Cilium Hubble UI. It serves as the API server that bridges the Hubble UI
frontend with Hubble Relay, providing service map data and network flow information. The backend queries the Kubernetes
API to discover services, pods, and network policies, and streams flow data from Hubble Relay to enable real-time
visualization of service dependencies and network traffic in Kubernetes clusters.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Cilium® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
