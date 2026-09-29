## About this Helm chart

This is a Cilium Helm chart built from the upstream Cilium Helm chart and using a hardened configuration with Docker
Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/cilium`
- `dhi/cilium-operator`
- `dhi/hubble-relay`
- `dhi/hubble-ui`
- `dhi/hubble-ui-backend`
- `dhi/cilium-envoy`
- `dhi/cilium-certgen`
- `dhi/cilium-clustermesh-apiserver`
- `dhi/cilium-startup-script`
- `dhi/ztunnel`
- `dhi/spire-agent`
- `dhi/spire-server`
- `dhi/busybox`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)

## About Cilium

Cilium is a networking, observability, and security solution with an eBPF-based dataplane. It provides a simple flat
Layer 3 network with the ability to span multiple clusters in either a native routing or overlay mode. It is L7-protocol
aware and can enforce network policies on L3-L7 using an identity-based security model that is decoupled from network
addressing.

Cilium includes Hubble, a fully distributed networking and security observability platform built on top of Cilium and
eBPF. Hubble provides deep visibility into service-to-service communication with a network flow log, a service map, and
integration with Grafana and Prometheus.

For more details, visit https://cilium.io/.

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
