## About Crane

Crane is a tool for interacting with remote images and registries. It allows to efficiently inspect, verify and
manipulate containers, manifests and image layers as well as checking cryptographic signatures.

### Key Features

- **Container Image Manipulation**: Pull, push, delete, copy, and inspect container images
- **Multi-Platform Support**: Inspect or copy images across different platforms (e.g., `linux/amd64`, `arm64`, etc.)
- **Manifest and Layer Tools**: Work with manifests, configs, layers, and blobs
- **Authentication Support**: Supports various authentication methods including Docker credential helpers
- **Efficient and Scriptable**: Built for automation with clean, minimal output and fast performance
- **Cross-platform**: Available for Linux, macOS, and Windows

### Common Use Cases

- **Image Debugging**: Examine image manifests, layers, and configs
- **Cross-Registry Syncing**: Copy images between different registries
- **Selective Layer Access**: Download or inspect individual layers
- **Multi-platform Image Handling**: View and manipulate image variants for different OS/architectures
- **CI/CD Automation**: Use in pipelines for efficient registry interactions
- **Image Signing & SBOM Integration**: Combine with tools like cosign and SBOM generators

### Registry Support

Crane works with any OCI-compliant registry, including:

- Docker Hub
- Amazon ECR
- Google Container Registry (GCR)
- Azure Container Registry (ACR)
- GitHub Container Registry (GHCR)
- Harbor
- Quay.io
- And many others

### Getting Started

The `crane` CLI offers a wide range of commands for image and registry manipulation. Some common operations include:

- `crane pull` - Pull an image and save it as a tarball
- `crane push` - Push a tarball or image to a registry
- `crane copy` - Copy an image from one registry to another
- `crane digest` - Get the digest of an image
- `crane config` - Fetch and inspect image configuration
- `crane manifest` - Fetch and inspect the raw manifest
- `crane ls` - List repositories or tags in a registry
- `crane delete` - Delete an image from a registry
- `crane export` - Export image layers and metadata
- `crane append` - Append layers to an existing image

This Docker Hardened Image provides a secure, minimal environment for running Crane operations in containerized
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
