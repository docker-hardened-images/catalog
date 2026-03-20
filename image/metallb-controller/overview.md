## About MetalLB Controller

MetalLB is a load-balancer implementation for bare metal Kubernetes clusters, using standard routing protocols. The
controller component is a Deployment that runs as a centralized control plane and is responsible for managing IP address
allocations for LoadBalancer services. It watches for service changes and assigns IP addresses from configured pools,
coordinating with the speaker components to announce these addresses to the network. The controller handles IP address
management, service endpoint monitoring, and configuration validation.

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
