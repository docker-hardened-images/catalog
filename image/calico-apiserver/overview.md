## About Calico API Server

Calico API Server is an aggregated extension API server for Kubernetes. It registers the `projectcalico.org/v3` API
group with the Kubernetes API aggregation layer so you can manage Calico resources (network policies, IP pools, BGP
configuration, Felix settings, and related objects) with `kubectl` without using `calicoctl`.

The component runs as a Deployment (typically in the `calico-apiserver` namespace), listens on HTTPS port 5443, and
reads Calico configuration from the cluster datastore when `DATASTORE_TYPE=kubernetes` (internal `crd.projectcalico.org`
CRDs). The Tigera Operator deploys and manages it through the `APIServer` custom resource when Calico is installed in
legacy API server mode.

Calico 3.32 and later prefer **native `projectcalico.org/v3` CRDs**, which expose the same APIs as standard Kubernetes
CRDs and do not require this aggregated server. The `calico-apiserver` image remains relevant for **backwards
compatibility** on clusters that have not migrated off API server mode.

For complete documentation, architecture details, and deployment guides, see the official Calico documentation at
https://docs.tigera.io/calico/latest/operations/install-apiserver.

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
