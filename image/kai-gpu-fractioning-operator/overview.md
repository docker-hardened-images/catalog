## About KAI GPU Fractioning Operator

GPU Fractioning lets multiple pods share a single GPU with enforced memory boundaries. It runs alongside KAI Scheduler:
the scheduler decides which fraction of which GPU a workload gets, and GPU Fractioning enforces that memory boundary on
the node and exports per-pod metrics.

The operator is the controller of the stack. It reconciles the `GpuFractioningConfig` custom resource and rolls out the
node-level components as DaemonSets to the selected GPU nodes: the NRI plugin that injects per-container GPU memory
limits at container creation, and the NVIDIA MPS control daemon with GPU memory accounting enabled.

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
