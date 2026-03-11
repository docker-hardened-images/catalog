## About this Helm chart

This is a Crossplane Docker Hardened Helm chart built from the upstream Crossplane Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/crossplane`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://docs.crossplane.io/](https://docs.crossplane.io/)

## About Crossplane

Crossplane is an open source Kubernetes add-on that enables platform teams to assemble infrastructure from multiple
vendors and expose higher level self-service APIs for application teams to consume. It transforms your Kubernetes
cluster into a universal control plane, allowing you to manage infrastructure and applications using the Kubernetes API.

Crossplane extends Kubernetes with:

- **Providers** that enable Crossplane to provision infrastructure on external services
- **Managed Resources** that represent external infrastructure as Kubernetes objects
- **Compositions** that define how to create multiple managed resources as a single unit
- **Composite Resources** that provide custom APIs for your platform

Official documentation: https://docs.crossplane.io/

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Crossplane® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
