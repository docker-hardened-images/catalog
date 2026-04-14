## About kube-rbac-proxy

kube-rbac-proxy is a small HTTP proxy for a single upstream, that can perform RBAC authorization against the Kubernetes
API using [SubjectAccessReview](https://kubernetes.io/docs/reference/access-authn-authz/authorization/).

In Kubernetes clusters without NetworkPolicies any Pod can perform requests to every other Pod in the cluster. This
proxy was developed in order to restrict requests to only those Pods, that present a valid and RBAC authorized token or
client TLS certificate.

For more information, visit the official repository: https://github.com/brancz/kube-rbac-proxy

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
