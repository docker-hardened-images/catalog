## About k8s-sidecar

k8s-sidecar is a Kubernetes sidecar container designed to collect ConfigMaps and Secrets with specified labels and store
the included files in a local folder. It runs alongside your main application container in a Kubernetes pod,
automatically synchronizing configuration files from ConfigMaps and Secrets as they change in the cluster. The sidecar
provides a health endpoint for readiness and liveness probes, supports webhook notifications on configuration changes,
and can handle both ConfigMaps and Secrets with flexible filtering options.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
