## About Dapr Injector

The Dapr® Sidecar Injector is a Kubernetes admission controller that automatically injects the Dapr runtime (daprd)
sidecar container into annotated pods. It acts as a mutating webhook that watches for pod creation events and patches
them to include the Dapr sidecar, simplifying deployment and ensuring consistent Dapr configuration across your cluster.

For more details, see https://docs.dapr.io/concepts/dapr-services/sidecar-injector/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Dapr® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
