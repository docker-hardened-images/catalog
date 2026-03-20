## About Cilium Startup Script

The Cilium Startup Script is a utility component within the Cilium ecosystem designed to execute startup scripts on
Kubernetes nodes. It runs as a privileged DaemonSet that uses `nsenter` to execute commands in the host's namespace,
enabling node-level configuration and initialization tasks. The script monitors for changes through a checkpoint-based
system that ensures idempotent execution, running the provided startup script only when changes are detected. It reads
the script content from the `STARTUP_SCRIPT` environment variable and executes it on the host using `nsenter` with full
namespace access, making it useful for system configuration, kernel parameter tuning, and one-time node setup tasks that
need to run before or alongside Cilium agents.

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
