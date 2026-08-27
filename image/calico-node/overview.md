## About Calico CNI

Calico Node is Calico's per-host DaemonSet container image. Provides CNI networking and policy for Kubernetes.

Calico Node is deployed to every node (on Kubernetes, by a DaemonSet), and runs three internal daemons:

- **Felix:** The Calico daemon that runs on every node and provides endpoints.
- **BIRD:** The BGP daemon that distributes routing information to other nodes.
- **confd:** A daemon that watches the Calico datastore for config changes and updates BIRD’s config files.

Calico is an open-source networking and network security solution for containers, virtual machines, and native
host-based workloads. It provides a highly scalable networking and network policy solution that uses standard Linux
networking tooling, including iptables, eBPF, and kernel routing tables.

For more information about Calico Node, visit https://docs.tigera.io/calico/latest/reference/configure-calico-node

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Calico® is a trademark of Tigera, Inc. All rights in the mark are reserved to Tigera, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
