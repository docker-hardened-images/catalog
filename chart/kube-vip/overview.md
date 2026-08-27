## About this Helm chart

This is a kube-vip Docker Hardened Helm chart built from the upstream kube-vip Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/kube-vip`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/kube-vip/helm-charts](https://github.com/kube-vip/helm-charts)

### About kube-vip

kube-vip provides Kubernetes clusters with a virtual IP and load balancer for both the control plane and Services of
type LoadBalancer without relying on any external hardware or software. It was designed as a small, self-contained
Highly-Available solution for all environments, especially bare-metal, edge, and virtualization deployments.

For more details, visit https://kube-vip.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
