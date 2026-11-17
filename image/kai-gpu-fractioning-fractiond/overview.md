## About KAI GPU Fractioning Fractiond

GPU Fractioning lets multiple pods share a single GPU with enforced memory boundaries. fractiond is its node-level NRI
plugin: it registers with the container runtime and, when a pod carrying GPU-memory annotations is created, injects the
per-container GPU memory request and limit into the container before it starts, together with the MPS pipe mount.

The NVIDIA driver enforces the injected limit as a hard cap, so a container cannot allocate beyond its share and affect
its neighbors on the same GPU. The operator runs fractiond as a DaemonSet on the GPU nodes, with the metrics sidecar
alongside it.

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
