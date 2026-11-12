## About Notation

Notation is a CLI tool for developers and operators that provides a standard way to sign and verify OCI artifacts. Its
main purpose is to secure container images and related artifacts in registries and CI/CD pipelines. It supports artifact
signing, signature verification, trust policy enforcement, and integration with pluggable key managers such as AWS KMS
and Azure Key Vault. Notation uses the OCI Referrers API to store and discover signatures in OCI-compliant registries.

The tool can secure a wide range of artifacts, from container images to Helm charts and SBOMs, making it useful for both
small projects and enterprise supply chains. Notation excels at ensuring only trusted, signed artifacts are deployed,
reducing the risk of tampering and enabling compliance in Kubernetes and automated workflows.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Notary® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
