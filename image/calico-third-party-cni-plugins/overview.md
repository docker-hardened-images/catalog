## About Calico Third-Party CNI Plugins

Calico Third-Party CNI Plugins is the init-container image Calico uses to stage upstream CNI binaries onto each node:
host-local, portmap, loopback, tuning, and flannel. The Tigera Operator runs it as the `cni-plugins` init container on
`calico-node` before `install-cni` copies those binaries onto the host.

This image is not a standalone networking stack. It is meant to be consumed by the operator (or an equivalent DaemonSet)
as `calico/third-party-cni-plugins`.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Calico® is a trademark of Tigera, Inc. All rights in the mark are reserved to Tigera, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
