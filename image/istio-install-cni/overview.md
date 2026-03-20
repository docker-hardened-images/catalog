## About Istio Install CNI

Istio Install CNI is a specialized component responsible for installing and configuring the Istio Container Network
Interface (CNI) plugin on Kubernetes nodes. This plugin is a critical infrastructure component that enables traffic
capture and redirection without requiring elevated privileges (NET_ADMIN capability) in the application sidecar proxy.

The CNI plugin replaces the traditional init-container approach that previously required running with elevated security
capabilities. By performing network configuration at the node level during pod startup, Istio CNI allows application
containers to run with minimal required privileges, significantly improving security posture.

Key responsibilities of Istio Install CNI:

- **CNI Plugin Installation**: Deploys the Istio CNI plugin binary to Kubernetes nodes
- **Network Configuration**: Configures iptables rules and network namespaces for traffic redirection
- **Pod Traffic Capture**: Intercepts inbound and outbound traffic for sidecar proxy injection
- **Privilege Reduction**: Eliminates the need for elevated capabilities in application containers
- **Automatic Node Setup**: Automatically configures nodes as they join the cluster
- **Configuration Management**: Handles CNI configuration file generation and updates
- **Node Daemonset Operation**: Runs as a DaemonSet to ensure coverage across all cluster nodes
- **Compatibility Management**: Ensures compatibility with various Kubernetes distributions and container runtimes

For more information about Istio CNI, visit https://istio.io/latest/docs/setup/additional-setup/cni/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Istio® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
