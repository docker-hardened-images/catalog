## About the Knative Serving controller

The controller is a component of the Knative Serving control plane. It runs the reconcilers that watch the Knative
Serving API resources (Services, Configurations, Routes, and Revisions) and drives the cluster toward the desired state,
creating and updating the underlying Kubernetes Deployments, autoscaling resources, and networking objects that run and
route serverless workloads. It runs leader election so a single instance owns reconciliation at a time.

Use this image when you need a hardened, minimal container image for running the Knative Serving controller as part of a
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
