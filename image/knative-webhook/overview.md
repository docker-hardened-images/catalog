## About the Knative Serving webhook

The webhook is a control-plane component of Knative Serving. It runs as a Kubernetes admission controller that
intercepts API requests for Knative Serving resources: it applies defaults to those resources, validates that changes
are well formed, and validates the Serving ConfigMaps. This keeps Knative Serving configuration consistent and rejects
invalid changes before they are persisted.

Use this image when you need a hardened, minimal container image for running the Knative Serving webhook as part of a
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
