## About ORAS (OCI Registry As Storage)

ORAS is a tool for working with OCI Artifacts. It treats the registry as a generic artifact store, enabling you to push,
pull, copy, and discover various content types beyond container images.

### Key Features

- **OCI Artifact Management**: Push, pull, copy, and discover OCI artifacts in registries
- **Multi-format Support**: Work with various content types including Helm charts, WASM modules, policy files, and more
- **Registry Compatibility**: Works with any OCI-compliant registry
- **Authentication**: Supports various authentication methods including Docker credential helpers
- **Cross-platform**: Available for Linux, macOS, and Windows

### Common Use Cases

- **Supply Chain Artifacts**: Store and manage software bills of materials (SBOMs), vulnerability reports, and policy
  files
- **Helm Chart Distribution**: Push and pull Helm charts as OCI artifacts
- **WebAssembly Modules**: Distribute WASM modules through container registries
- **Configuration Management**: Store and version configuration files and policies
- **Software Distribution**: Distribute any type of software artifact through OCI registries

### Registry Support

ORAS works with any OCI-compliant registry, including:

- Docker Hub
- Amazon ECR
- Google Container Registry (GCR)
- Azure Container Registry (ACR)
- GitHub Container Registry (GHCR)
- Harbor
- Quay.io
- And many others

### Getting Started

The ORAS CLI provides a simple interface for managing OCI artifacts. Common operations include:

- `oras push` - Push artifacts to a registry
- `oras pull` - Pull artifacts from a registry
- `oras copy` - Copy artifacts between registries
- `oras discover` - Discover artifacts and their relationships
- `oras attach` - Attach artifacts to existing content

This Docker Hardened Image provides a secure, minimal environment for running ORAS operations in containerized workflows
and CI/CD pipelines.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
