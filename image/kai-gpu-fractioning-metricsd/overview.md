## About KAI GPU Fractioning Metrics Daemon

GPU Fractioning lets multiple pods share a single GPU with enforced memory boundaries. metricsd exports per-pod GPU
memory and utilization metrics for the shared GPUs in Prometheus format, attributing each GPU process to its pod through
the mapping that fractiond records.

The operator runs metricsd as a sidecar container in the fractiond DaemonSet. It reads GPU state through NVML, using the
driver library that the NVIDIA container runtime injects from the host.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

NVIDIA® is a trademark and/or registered trademark of NVIDIA Corporation. Kubernetes® is a registered trademark of The
Linux Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.

This listing is prepared by Docker. All other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
