## About Crossplane

Crossplane is an open source Kubernetes add-on that enables platform teams to assemble infrastructure from multiple
vendors and expose higher-level self-service APIs for application teams.

For more details, visit https://crossplane.io/.

## About this image

This Docker Hardened Image packages the Crossplane CLI and controller binary:

- `crossplane`: Crossplane command-line and controller entrypoint

This image also includes Kubernetes assets used by Crossplane initialization flows:

- `/crds`
- `/webhookconfigurations/usage.yaml`

## About Docker Hardened Images

Docker Hardened Images are built to meet high security and compliance standards. They provide a trusted foundation for
containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting into existing
Docker workflows.

## Trademarks

Crossplane® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
