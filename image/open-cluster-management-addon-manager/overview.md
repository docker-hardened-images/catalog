## About Open Cluster Management Addon Manager

The addon manager is a Kubernetes controller in the hub cluster that configures the installation of addon agents for
each managed cluster. It applies manifests to managed clusters via the ManifestWork API and can optionally handle
lifecycle management of CSRs and RBAC permissions for addon agents.

OCM Add-ons provide a clear framework that allows developers to easily add their software to OCM and make it
multicluster aware. Add-ons are simple to write and are fully documented and maintained according to specifications in
the [addon-framework](https://github.com/open-cluster-management-io/addon-framework) repository.

For more details, visit the
[OCM Add-on documentation](https://open-cluster-management.io/docs/concepts/add-on-extensibility/addon/).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Open Cluster Management™ is a trademark of The Linux Foundation®. All rights in the mark are reserved to The Linux
Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
