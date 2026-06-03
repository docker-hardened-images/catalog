## About this Helm chart

This is a Harbor Docker Hardened Helm chart built from the upstream Harbor Helm chart and using a hardened configuration
with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/harbor-core`
- `dhi/harbor-jobservice`
- `dhi/harbor-registry`
- `dhi/harbor-registryctl`
- `dhi/harbor-trivy-adapter`
- `dhi/harbor-exporter`
- `dhi/harbor-portal`
- `dhi/harbor-db`
- `dhi/harbor-redis`
- `dhi/nginx`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://goharbor.io/docs/latest/install-config/harbor-ha-helm/](https://goharbor.io/docs/latest/install-config/harbor-ha-helm/)

## About Harbor

Harbor is an open source trusted cloud native registry project that stores, signs, and scans content. Harbor solves
common challenges by delivering trust, compliance, performance, and interoperability. It fills a gap for organizations
and applications that cannot use a public or cloud-based registry, or want a consistent experience across clouds.

Harbor supports the OCI Distribution Specification and provides role-based access control, vulnerability scanning via
Trivy, replication policies, image signing with Notary/Cosign, and a rich web portal for managing registries and
artifacts.

For more details, visit https://goharbor.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Harbor® is a trademark of the Cloud Native Computing Foundation. All rights in the mark are reserved to the Cloud Native
Computing Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement,
or affiliation.
