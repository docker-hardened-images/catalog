## About trust-manager

trust-manager is a Kubernetes operator from the cert-manager project that distributes trust bundles across clusters. It
assembles X.509 CA certificates from multiple sources and syncs them into ConfigMaps or Secrets in every namespace where
your workloads need them.

The trust-manager image is used with the companion image trust-mananger-package, which provides the default CA
certificate bundle used by trust-manager. When installed via Helm, trust-manager has a dependency on cert-manager for
provisioning an application certificate unless you explicitly opt to use a Helm-generated certificate instead.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Cert Manager™ and Kubernetes® are trademarks of the Linux Foundation. All rights in the mark are reserved to the Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
