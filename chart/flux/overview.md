## About this Helm chart

This is a Flux Docker Hardened Helm chart built from the upstream Flux Helm chart and using a hardened configuration
with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/flux-cli`
- `dhi/fluxcd-helm-controller`
- `dhi/fluxcd-image-automation-controller`
- `dhi/fluxcd-image-reflector-controller`
- `dhi/fluxcd-kustomize-controller`
- `dhi/fluxcd-notification-controller`
- `dhi/fluxcd-source-controller`
- `dhi/fluxcd-source-watcher`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://fluxcd.io/flux/installation/](https://fluxcd.io/flux/installation/)

## About Flux

Flux is a set of continuous and progressive delivery solutions for Kubernetes that are open and extensible. It is a CNCF
Graduated project that enables GitOps workflows by reconciling cluster state from Git repositories, Helm charts, and OCI
artifacts. Flux is composed of multiple specialized controllers that handle source management, kustomization, Helm
releases, notifications, and image automation.

For more details, visit https://fluxcd.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Flux® is a trademark of The Linux Foundation. All rights in the mark are reserved to The Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
