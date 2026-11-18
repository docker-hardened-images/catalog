## About kube-api-auth

kube-api-auth is a webhook token authenticator that lets a downstream Kubernetes cluster verify Rancher-issued user
tokens without a live connection back to Rancher. It answers `TokenReview` requests from the local kube-apiserver by
checking the bearer token against the `ClusterAuthToken` and `ClusterUserAttribute` resources that Rancher mirrors into
the cluster, and returns the user and groups the API server should trust.

Rancher deploys it as a DaemonSet on the control plane nodes of clusters that use the authorized cluster endpoint. Each
kube-api-auth minor release line serves one or more Rancher minor releases.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.

Rancher is associated with SUSE. This listing is prepared by Docker. All third-party product names, logos, and
trademarks are the property of their respective owners and are used solely for identification. Docker claims no interest
in those marks, and no affiliation, sponsorship, or endorsement is implied.
