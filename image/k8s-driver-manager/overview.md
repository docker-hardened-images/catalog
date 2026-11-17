## About K8s Driver Manager

K8s Driver Manager is a component of the NVIDIA GPU Operator that manages the lifecycle of NVIDIA GPU drivers on
Kubernetes nodes. Its `driver-manager` binary runs preflight checks and orchestrates safe driver upgrades - draining GPU
workloads, evicting pods, and uninstalling the previous driver version before a new one is installed. Its `vfio-manage`
binary binds and unbinds GPUs to and from the VFIO driver, which the GPU Operator uses for GPU passthrough (vGPU)
workloads. Both binaries require root and access to the host's mount namespace and kernel module tools; see "Root and
privileged requirement" in the usage guide.

For more details, visit https://github.com/NVIDIA/k8s-driver-manager.

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
