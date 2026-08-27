## About NVIDIA GPU Operator

The NVIDIA GPU Operator automates the management of the NVIDIA software components required to provision and monitor
GPUs in Kubernetes clusters. Using the operator pattern, it reconciles a `ClusterPolicy` custom resource to manage the
GPU driver, container toolkit, device plugin, feature discovery, DCGM monitoring, and validation components as
DaemonSets, removing the need to install and maintain these components by hand on every node.

This image ships the operator controller together with the `nvidia-validator` (which verifies driver, toolkit, device
plugin, and CUDA workload readiness on GPU nodes), the `vectorAdd` CUDA validation sample the validator runs, `kubectl`,
and the operand manifests the controller renders at runtime together with the operator CRDs.

For more information, visit the official repository: https://github.com/NVIDIA/gpu-operator

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

NVIDIA® and CUDA® are trademarks and/or registered trademarks of NVIDIA Corporation. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
