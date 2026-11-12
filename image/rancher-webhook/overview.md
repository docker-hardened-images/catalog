## About Rancher Webhook

Rancher Webhook is a validating and mutating admission webhook for Kubernetes. Rancher runs it in its local cluster and
in every downstream cluster it manages, where it checks and adjusts Rancher resources and some Kubernetes resources,
such as namespaces, before the API server stores them.

Each Rancher Webhook minor release line belongs to one Rancher minor release, and Rancher installs it through the
`rancher-webhook` Helm chart into the `cattle-system` namespace.

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
