### About Cilium Envoy

Cilium integrates a specialized, minimal build of the Envoy proxy to enforce Layer 7 (L7) network policies, provide
traffic management (like ingress and load balancing), and offer observability within a Kubernetes cluster.

This image is designed specifically for use in Kubernetes environments and requires the Cilium stack to function. It
cannot operate as a standalone proxy and is not intended for direct execution outside of the Cilium service mesh
context.

For more details, see https://github.com/cilium/proxy.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Cilium® and Kubernetes® are registered trademarks of the Linux Foundation. All rights in the mark are reserved to the
Linux Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
