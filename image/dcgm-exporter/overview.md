## About NVIDIA DCGM Exporter

DCGM Exporter is a Prometheus exporter for NVIDIA GPU metrics, built on top of the NVIDIA Data Center GPU Manager (DCGM)
library. It exposes GPU telemetry (including utilization, memory usage, temperature, power draw, and hardware profiling
counters) as a Prometheus-compatible `/metrics` endpoint on port 9400. Common use cases include GPU cluster
observability, ML training and inference monitoring, and HPC job telemetry.

The exporter integrates with the NVIDIA container runtime to access GPU devices and supports Kubernetes deployments via
the NVIDIA GPU Operator's built-in dcgm-exporter integration or the upstream Helm chart. For full documentation, see
[docs.nvidia.com](https://docs.nvidia.com/datacenter/cloud-native/gpu-telemetry/dcgm-exporter.html).

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
