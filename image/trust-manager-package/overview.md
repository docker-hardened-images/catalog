## About Trust Manager Package

Trust Manager is a Kubernetes operator from the Cert Manager project that distributes trust bundles across clusters. It
assembles X.509 CA certificates from multiple sources and syncs them into ConfigMaps or Secrets in every namespace where
your workloads need them.

The Trust Manager Package image is a companion container that provides the default CA certificate bundle used by Trust
Manager. It contains a small Go binary and a JSON-formatted trust bundle derived from the Debian `ca-certificates`
package. When trust-manager starts, it runs this image as an init container to copy the CA bundle into the trust-manager
pod, which then distributes it to workloads across the cluster via `Bundle` resources with `useDefaultCAs: true`.

This image is versioned based on the Debian `ca-certificates` package version and is available in variants for different
Debian releases (bookworm, trixie).

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
