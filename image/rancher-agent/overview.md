## About Rancher Agent

Rancher Agent connects a Kubernetes cluster to the Rancher server that manages it. Rancher runs it as the
`cattle-cluster-agent` Deployment in every downstream cluster, where it carries Rancher's API traffic to the cluster and
installs Rancher's system charts.

Each Rancher Agent release matches one Rancher release, and Rancher deploys the agent of its own version.

For more details, visit https://github.com/rancher/rancher and the Rancher documentation at
https://ranchermanager.docs.rancher.com/.

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
