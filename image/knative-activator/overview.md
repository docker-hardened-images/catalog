## About the Knative Serving activator

The activator is a component of the Knative Serving data plane. When a Revision is scaled to zero, or does not yet have
enough capacity to handle incoming traffic, requests are routed through the activator. It buffers those requests,
reports the demand to the autoscaler so that pods can be scaled up, and forwards the traffic to the Revision once
capacity becomes available.

Use this image when you need a hardened, minimal container image for running the Knative Serving activator as part of a
Knative Serving deployment.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Knative™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
