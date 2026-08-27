## About regctl

regctl is a CLI interface for Docker and OCI registries that provides efficient registry operations without requiring a
container runtime or privileged access to the local host.

### Key Features

- **Registry Operations**: Query tag listings, repository listings, and remotely inspect image contents
- **Efficient Copying**: Copy and retag images, only pulling layers when required, without changing image digests
- **Multi-platform Support**: Full support for multi-platform images and architecture-specific operations
- **OCI Artifacts**: Query, create, and copy OCI artifacts, storing arbitrary data in OCI registries
- **Content Manipulation**: Mutate existing images including annotations, labels, timestamps, and layer modifications
- **No Runtime Required**: Operates without container runtime or privileged access

### Common Use Cases

- **Image Management**: Copy, retag, and inspect container images across registries
- **Multi-platform Builds**: Generate multi-platform manifests from separately built images
- **Registry Migration**: Efficiently migrate images between registries
- **Content Inspection**: Examine image contents, manifests, and metadata without pulling images
- **OCI Artifact Storage**: Use registries as generic artifact stores for any type of content
- **Supply Chain Operations**: Work with signatures, SBOMs, and other supply chain artifacts

### Registry Compatibility

regctl works with any OCI-compliant registry, including:

- Docker Hub
- Amazon ECR
- Google Container Registry (GCR)
- Azure Container Registry (ACR)
- GitHub Container Registry (GHCR)
- Harbor
- Quay.io
- GitLab Container Registry
- And many others

### Getting Started

The regctl CLI provides intuitive commands for common registry operations:

- `regctl image` - Image operations (copy, delete, inspect, manifest)
- `regctl repo` - Repository operations (list tags, delete)
- `regctl tag` - Tag operations (list, delete)
- `regctl blob` - Blob operations (get, put, delete)
- `regctl artifact` - OCI artifact operations
- `regctl index` - Multi-platform index operations

This Docker Hardened Image provides a secure, minimal environment for running regctl operations in containerized
workflows and CI/CD pipelines.

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
