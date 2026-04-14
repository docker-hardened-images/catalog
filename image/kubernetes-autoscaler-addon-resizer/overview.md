## About Kubernetes Addon Resizer

The Kubernetes Addon Resizer (also known as pod_nanny or addon-resizer) is a container that watches over another
container in a deployment and vertically scales the dependent container up and down. It scales resources linearly based
on the number of nodes in the cluster.

The addon-resizer is commonly used as a sidecar container with Kubernetes addons such as metrics-server, heapster, and
kube-state-metrics to automatically adjust resource allocations based on cluster size.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
