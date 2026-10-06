## About Calico

Calico is an open source networking and network security solution for containers, virtual machines, and native
host-based workloads. This image ships the Calico combined binary, `calico`, which packages the Calico components behind
a single executable with `component`, `ctl`, `health`, and `version` subcommands. The Tigera Operator deploys these
components as part of a full Calico stack. The image also includes the CSI node driver registrar that registers the
Calico CSI driver with the kubelet.

For complete documentation, architecture details, and deployment guides, see the official Calico documentation at
https://docs.tigera.io/calico.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Calico® is a trademark of Tigera, Inc. All rights in the mark are reserved to Tigera, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Kubernetes® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
