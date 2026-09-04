## About Kiali

Kiali is an open-source observability console for Istio and other service meshes. It helps operators and developers
understand service topology, request rates, error rates, and configuration health across Kubernetes or OpenShift
clusters. Kiali can run against a live cluster or in offline mode against exported manifests and metrics.

This image ships the hardened `kiali-server` package binary at `/usr/bin/kiali`, with the upstream entrypoint path
`/opt/kiali/kiali` preserved via symlink for compatibility with existing manifests.

For full documentation, see the [Kiali project documentation](https://kiali.io/docs/).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kiali is a trademark of the Kiali project contributors. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.
