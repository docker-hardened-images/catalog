## About Contour

Contour is a Kubernetes ingress controller that uses Envoy proxy to provide dynamic configuration updates and
high-performance load balancing. Contour supports standard Kubernetes Ingress resources, its own HTTPProxy custom
resource for advanced features, and the Gateway API for vendor-neutral service networking.

Contour works by deploying the Envoy proxy as a reverse proxy and load balancer, while Contour itself acts as the
control plane that translates Kubernetes resources into Envoy configuration. This architecture provides a lightweight
footprint while maintaining dynamic configuration capabilities.

For more details, visit https://projectcontour.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Contour™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
