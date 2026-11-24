## About KAI Scheduler NUMA Placement Exporter

KAI Scheduler is a Kubernetes scheduler that optimizes GPU resource allocation for AI and machine learning workloads.
Its NUMA plugin places topology-sensitive pods so that their CPUs, memory and devices sit close together on a NUMA node.

The NUMA placement exporter is the per-node agent behind that plugin. KAI's operator runs it as a DaemonSet; it reads
the kubelet's pod resource assignments and records the NUMA placement each pod actually received as a pod annotation, so
the scheduler accounts for observed rather than predicted placement.

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
