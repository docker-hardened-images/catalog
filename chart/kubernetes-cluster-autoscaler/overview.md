## About this Helm chart

This is a Kubernetes Cluster Autoscaler Docker Hardened Helm chart built from the upstream Kubernetes Cluster Autoscaler
Helm chart and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/kubernetes-cluster-autoscaler`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/charts/cluster-autoscaler/README.md](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/charts/cluster-autoscaler/README.md)

## About Kubernetes Cluster Autoscaler

Kubernetes Cluster Autoscaler automatically adjusts the size of your Kubernetes cluster by adding or removing nodes
based on resource demands. When pods cannot be scheduled due to insufficient resources, the Cluster Autoscaler
provisions new nodes to accommodate them. It scales down underutilized nodes while respecting pod disruption budgets,
node constraints, and availability. The Cluster Autoscaler integrates with AWS, Azure, and Google Cloud Platform and
works alongside the Horizontal Pod Autoscaler.

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
