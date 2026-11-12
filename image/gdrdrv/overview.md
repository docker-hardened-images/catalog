## About NVIDIA GDRCopy Driver

GDRCopy is a low-latency GPU memory copy library based on NVIDIA GPUDirect RDMA technology. Its kernel module, `gdrdrv`,
lets a CPU map GPU memory into its own address space, so small buffers move with far lower latency than a CUDA memcpy.

This image is the GDRCopy driver container the NVIDIA GPU Operator runs next to its driver container when
`gdrcopy.enabled` is set: it compiles `gdrdrv` for the node's kernel from the driver container's rootfs (on OpenShift
the Driver Toolkit compiles it), loads it, and unloads it when the pod stops, unless it is in use. It runs as root and
privileged, like the upstream container, because it loads a module into the host kernel.

For more information, visit the official repository: https://github.com/NVIDIA/gdrcopy

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

NVIDIA® is a trademark and/or registered trademark of NVIDIA Corporation. All rights in the mark are reserved to NVIDIA
Corporation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
