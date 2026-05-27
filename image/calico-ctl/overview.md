## About Calico CTL

Calico CTL (`calicoctl`) is the command-line tool for managing Calico network and security resources. It interfaces with
the Calico datastore and Kubernetes API to configure IP pools, network policies, nodes, and related objects. The Tigera
Operator Helm chart uses this image in an init container to apply Calico custom resources during installation.

This Docker Hardened Image ships the `calicoctl` binary built from the Project Calico monorepo on a minimal static base.

For more information, see https://docs.tigera.io/calico/latest/reference/calicoctl/.

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
