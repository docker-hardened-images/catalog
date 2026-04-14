## About Hubble Proto

The Hubble Proto hardened image provides Protocol Buffer compiler plugins for generating Go code from proto definitions.
Hubble is the observability platform for Cilium, a cloud-native networking and security solution for Kubernetes.

This image contains three protoc plugins: `protoc-gen-go` for generating Go message types, `protoc-gen-go-grpc` for
generating gRPC service definitions, and `protoc-gen-go-json` for JSON marshaling support. The plugin versions match
those used in upstream Cilium's build tooling. The image contains only the protoc plugins themselves, not the `protoc`
compiler. These plugins can be copied into build environments where `protoc` is available, or used in multi-stage Docker
builds for reproducible code generation.

For more information about Hubble, visit the
[official Cilium documentation](https://docs.cilium.io/en/stable/gettingstarted/hubble/).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Cilium® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
