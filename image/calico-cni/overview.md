## About Calico CNI

Calico CNI is the Container Network Interface (CNI) plugin component of Calico, providing networking and network policy
enforcement for Kubernetes clusters. The CNI plugin is responsible for configuring network interfaces for pods, managing
IP address allocation, and enabling Calico's powerful network policy capabilities at the pod level.

Calico is an open-source networking and network security solution for containers, virtual machines, and native
host-based workloads. It provides a highly scalable networking and network policy solution that uses standard Linux
networking tooling, including iptables, eBPF, and kernel routing tables.

Key responsibilities of Calico CNI:

- **Pod Network Configuration**: Configures network interfaces and routing for pods during creation
- **IP Address Management (IPAM)**: Allocates and manages IP addresses from configured IP pools
- **Network Policy Enforcement**: Enables fine-grained network policy control at the pod level
- **BGP Peering Support**: Integrates with BGP for scalable network routing across nodes
- **Multiple Dataplane Support**: Works with iptables, eBPF, or Windows HNS dataplanes
- **CNI Chaining**: Supports chaining with other CNI plugins for advanced networking scenarios
- **Kubernetes Integration**: Native integration with Kubernetes NetworkPolicy resources
- **Cross-Subnet Communication**: Handles VXLAN or IP-in-IP encapsulation for cross-subnet traffic

For more information about Calico CNI, visit https://docs.tigera.io/calico/latest/reference/cni-plugin/configuration.

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
