## About the Knative Serving autoscaler

The autoscaler is a component of the Knative Serving control plane. It collects per-revision request metrics reported by
the activator and the queue-proxy sidecars, aggregates them over stable and panic windows, and computes the desired
number of pods for each Revision. Based on those decisions it scales Revisions up and down, including scaling to zero
when a Revision receives no traffic.

Use this image when you need a hardened, minimal container image for running the Knative Serving autoscaler as part of a
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
