## About Headlamp

Headlamp is a fully-featured, user-friendly and extensible web UI for Kubernetes. Maintained as a Kubernetes SIG project
under the `kubernetes-sigs` GitHub organization, it provides a modern interface for managing single or multiple
clusters, with a plugin system that lets the dashboard be extended for application-specific workflows.

### Key Features

- **Multi-cluster support**: Switch between clusters from a single interface using your existing kubeconfig
- **RBAC-aware UI**: Actions and resources are gated by the permissions of the authenticated user
- **Extensible plugin system**: Ship custom views, sidebar items, and resource details via JavaScript plugins
- **In-cluster or desktop**: Run as a container deployed to the cluster, or as a standalone Electron desktop application
- **Resource management**: Browse, edit, and create Kubernetes resources with a built-in Monaco-based editor
- **Live logs and exec**: Stream pod logs and open interactive shells against containers
- **Helm integration**: Browse and manage Helm releases when the backend is configured with Helm support

### What's Included

This image bundles the Headlamp backend server (`headlamp-server`) and the built React/TypeScript frontend assets. The
backend exposes the dashboard on port `4466` and serves both the frontend and the Kubernetes API proxy from a single
process.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation in the United States and other countries. All rights in
the mark are reserved to The Linux Foundation. Any use by Docker is for referential purposes only and does not indicate
sponsorship, endorsement, or affiliation.

Headlamp is a project of the Cloud Native Computing Foundation, hosted under the `kubernetes-sigs` GitHub organization.
The Headlamp name and logo are used here in accordance with the project's Apache-2.0 license and CNCF trademark policy.
Any use by Docker is for referential purposes only.
