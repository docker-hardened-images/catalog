## About Calico Kube Controllers

Calico Kube Controllers is a core component of the Calico networking stack for Kubernetes. It runs a set of background
control loops that keep Calico’s datastore in sync with the state of the cluster. The controller manages Calico-specific
resources such as IPAM allocations, workload endpoints, node entries, and Calico Network Policies. It helps ensure
unused IP addresses are reclaimed, stale endpoint objects are cleaned up, and Calico CRDs remain consistent as pods and
nodes are created, updated, or removed. Together with the Calico CNI plugin and Calico’s data plane components, Kube
Controllers maintains accurate, reliable networking state across the cluster.

For complete documentation, architecture details, and deployment guides, see the official Calico documentation at
https://docs.tigera.io/calico.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows. hannahSiimpl marked this conversation as resolved.

## Trademarks

Calico® is a trademark of Tigera, Inc. All rights in the mark are reserved to Tigera, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
