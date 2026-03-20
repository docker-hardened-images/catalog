## About Kubernetes VPA Admission Controller

The Kubernetes Vertical Pod Autoscaler (VPA) Admission Controller is a critical component of the VPA system that runs as
a mutating webhook in Kubernetes clusters. It intercepts pod creation and update requests to automatically set or modify
CPU and memory resource requests based on recommendations from the VPA Recommender. As part of the three-component VPA
architecture (Recommender, Updater, and Admission Controller), it ensures that new pods are created with optimal
resource requests without requiring manual intervention or pod restarts, enabling efficient resource utilization and
preventing resource starvation or waste in containerized workloads.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
