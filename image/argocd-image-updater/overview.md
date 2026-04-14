## About Argo CD Image Updater

[Argo CD Image Updater](https://github.com/argoproj-labs/argocd-image-updater) is a Kubernetes controller that
automatically updates container images of applications managed by Argo CD. It monitors container registries for new
versions and updates applications according to configurable policies.

Key features include:

- **Automatic image updates**: Continuously monitors registries and updates applications with new versions
- **Multiple update strategies**: Support for semantic versioning, digest-based updates, and latest tag tracking
- **Git write-back**: Write image updates back to Git repositories for full GitOps workflows
- **Multi-registry support**: Works with Docker Hub, ECR, GCR, ACR, Harbor, Quay, and other registries
- **Webhook integration**: Receive immediate notifications from registries for faster updates
- **Flexible configuration**: Per-application configuration via Argo CD Application annotations

Advanced capabilities:

- Version constraint support with semantic versioning rules
- Registry authentication with multiple credential types
- Direct parameter override or Git commit-based updates
- Argo CD ApplicationSet support
- Prometheus metrics and health endpoints
- GPG commit signing for Git write-back

## About Docker Hardened Images

Docker Hardened Images (DHI) are secure, minimal container images with near-zero CVEs, signed provenance, and complete
SBOM/VEX metadata. They provide a secure foundation for production workloads.

## Trademarks

Argo® is a registered trademark of The Linux Foundation. This image is not affiliated with or endorsed by The Linux
Foundation or the Argo project.
