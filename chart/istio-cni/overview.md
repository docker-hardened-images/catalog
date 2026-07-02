## About this Helm chart

This is an Istio CNI Docker Hardened Helm chart built from the upstream Istio
[istio-cni](https://github.com/istio/istio/tree/master/manifests/charts/istio-cni) Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/istio-install-cni` (CNI plugin installer)

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://istio.io/latest/](https://istio.io/latest/)

### About Istio CNI

The Istio CNI plugin replaces the `istio-init` init container that would otherwise be used to configure traffic
redirection in each pod. Instead, the CNI plugin handles the required `iptables` rules at the node level as a DaemonSet,
removing the need for pods to have `NET_ADMIN` and `NET_RAW` capabilities. This simplifies security policies and reduces
the privilege requirements for workloads in the mesh.

For more details, visit https://istio.io/latest/docs/setup/additional-setup/cni/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Istio® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
