## About csi-external-health-monitor-controller

`csi-external-health-monitor-controller` is a Kubernetes Container Storage Interface (CSI) sidecar component that
monitors the health of CSI volumes and reports anomalies to the Kubernetes API. It provides advanced health monitoring
capabilities beyond basic liveness probes, helping to detect volume failures early.

The component monitors volume health status, detects anomalies, and generates Kubernetes events when issues are found.
It provides health metrics and alerts, and integrates with the Kubernetes event system to provide visibility into volume
health across the cluster.

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
