## About Calico Typha

Calico Typha is a fan-out proxy for the Calico datastore. In large Kubernetes clusters, many Calico components
(calico-node, kube-controllers, and others) read and watch configuration from the backing datastore. Typha sits between
those clients and the datastore, aggregating updates and reducing load on etcd or the Kubernetes API server. Typha is
optional for small clusters but recommended when node counts grow.

For complete documentation, architecture details, and deployment guides, see the official Calico documentation at
https://docs.tigera.io/calico.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Calico® is a trademark of Tigera, Inc. All rights in the mark are reserved to Tigera, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
