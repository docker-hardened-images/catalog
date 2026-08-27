## About this Helm chart

This is a Zot Docker Helm chart built from the upstream Zot Helm chart and using a hardened configuration with Docker
Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/zot`
- `dhi/alpine-base`

To learn more about how to use this Helm chart you can visit the upstream documentation:
https://github.com/project-zot/helm-charts

### About Zot

Zot is a production-ready, vendor-neutral OCI-native container image registry with full support for the OCI distribution
and image specifications. It can be deployed as a single binary or as a clustered service and supports features such as
image signing, vulnerability scanning, sync between registries, and a built-in web UI.

For more details, visit https://zotregistry.dev/.

## Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
