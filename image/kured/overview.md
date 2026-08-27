## About Kured

Kured (Kubernetes Reboot Daemon) is an open-source daemonset that performs safe, automated node reboots in a Kubernetes
cluster when the underlying operating system indicates that a reboot is required. It is commonly used to apply kernel
patches and other OS-level updates that require a restart, while ensuring that cluster workloads remain available
throughout the process by cordoning and draining nodes before rebooting.

For more details, see https://github.com/kubereboot/kured.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Kured™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
