## About MetalLB Speaker

MetalLB is a load-balancer implementation for bare metal Kubernetes clusters, using standard routing protocols. The
speaker component is a DaemonSet that runs on each node and is responsible for announcing LoadBalancer services to the
network. It supports Layer 2 (ARP) mode for simple local network announcements and BGP mode for sophisticated routing
across networks. The speaker works in conjunction with the MetalLB controller to provide load balancing capabilities
equivalent to cloud provider implementations.

For more information and official documentation, visit https://metallb.io

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

MetalLB® and the MetalLB® logo are trademarks of the MetalLB project. All rights in the mark are reserved to the MetalLB
project. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
