## About this Helm chart

This is a Argo CD Image Updater Docker Hardened Helm chart built from the upstream Argo CD Helm chart and using a
hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/argocd-image-updater`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/README.md](https://github.com/argoproj/argo-helm/blob/main/charts/argo-cd/README.md)

## About Argo CD Image Updater

[Argo CD Image Updater](https://github.com/argoproj-labs/argocd-image-updater) is a Kubernetes controller that
automatically updates container images of applications managed by Argo CD. It monitors container registries for new
versions and updates applications according to configurable policies.

For more details, visit https://argo-cd.readthedocs.io/en/stable/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Argo® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
