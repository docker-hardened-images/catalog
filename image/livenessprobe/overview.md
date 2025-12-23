## About livenessprobe

`livenessprobe` is a Kubernetes Container Storage Interface (CSI) sidecar component that provides health checking
capabilities for CSI drivers. It monitors CSI driver endpoints for health status and reports liveness and readiness to
Kubernetes, ensuring CSI driver availability and proper lifecycle management.

The component probes CSI driver endpoints using gRPC health checks, integrates with Kubernetes health check mechanisms,
and is critical for ensuring CSI driver components remain available and responsive. It runs as a sidecar container
alongside CSI driver components in both controller and node pods.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
