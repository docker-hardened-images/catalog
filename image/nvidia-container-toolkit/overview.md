## About NVIDIA Container Toolkit

The NVIDIA Container Toolkit lets container runtimes such as containerd, CRI-O, and Docker run GPU-accelerated
containers. This image is the toolkit's Kubernetes operand: the container the NVIDIA GPU Operator deploys as a
privileged DaemonSet to install the toolkit onto cluster nodes and configure the node's container runtime.

It ships `nvidia-ctk-installer` (also reachable by its legacy `nvidia-toolkit` entrypoint name, which every GPU Operator
release execs) together with pre-extracted toolkit and libnvidia-container payloads under `/artifacts/deb` and
`/artifacts/rpm`, from which the installer copies binaries and libraries onto the host.

Because this image runs as a privileged, root DaemonSet that writes to host paths (`/usr/local/nvidia`, `/run/nvidia`),
it cannot run as a nonroot container; this matches the upstream operand and the GPU Operator's pod security context.

The toolkit and libnvidia-container payloads are built from source in Docker Hardened Images packages on Debian 13 and
are linked against glibc: nodes receiving the installed toolkit need glibc 2.38 or newer (for example Debian 13 or
Ubuntu 24.04). Nodes on older glibc lines should use the upstream NVIDIA operand image instead.

For more information, visit the official repository: https://github.com/NVIDIA/nvidia-container-toolkit

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
