## About KAI GPU Fractioning MPS Daemon

GPU Fractioning lets multiple pods share a single GPU with enforced memory boundaries. mpsd runs and supervises the
NVIDIA MPS control daemon on each GPU node with per-process GPU memory accounting enabled, restarting it if it stops,
and labels the node with the NVIDIA driver major version it reads through NVML.

The NVIDIA container runtime injects the host driver's NVML library and the MPS control binary into the container, so
the image carries neither. The operator runs mpsd as a DaemonSet on the GPU nodes.

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
