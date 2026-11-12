## About k8s-device-plugin

The NVIDIA k8s-device-plugin exposes NVIDIA GPUs to Kubernetes as attachable resources. It runs as a DaemonSet and
registers devices with the kubelet so that GPU-accelerated workloads can request GPU resources using the
`nvidia.com/gpu` resource name. Typical use cases include ML training and inference, HPC, and other GPU-accelerated
workloads that rely on CUDA or other NVIDIA libraries.

k8s-device-plugin supports features such as GPU time-slicing, Multi-Instance GPU (MIG), Multi-Process Service (MPS), GPU
Feature Discovery (GFD), and the Container Device Interface (CDI), enabling flexible GPU partitioning and improved
utilization in shared cluster environments.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

NVIDIA® is a registered trademark of NVIDIA Corporation. All rights in the mark are reserved to NVIDIA Corporation. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
