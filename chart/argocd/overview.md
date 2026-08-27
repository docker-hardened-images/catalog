## About this Helm chart

This is a Argo CD Docker Hardened Helm chart built from the upstream Argo CD Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/argocd`
- `dhi/dex`
- `dhi/redis`
- `dhi/redis-exporter`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/README.md](https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/README.md)

## About Argo CD

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes. It enables you to manage application
deployments and lifecycle directly from Git repositories, ensuring that your cluster state matches your desired
configuration.

For more details, visit https://argo-cd.readthedocs.io/en/stable/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Argo®, Dex™ and Kubernetes® are trademarks of the Linux Foundation. All rights in the mark are reserved to the Linux
Foundation. Redis® is a registered trademark of Redis Ltd. Any rights therein are reserved to Redis Ltd. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
