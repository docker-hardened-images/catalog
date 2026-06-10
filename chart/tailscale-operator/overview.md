## About this Helm chart

This is a Tailscale Operator Docker Hardened Helm chart built from the upstream Tailscale Kubernetes Operator Helm chart
and using a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/tailscale-operator` — the Kubernetes operator that manages Tailscale resources in the cluster
- `dhi/tailscale` — the Tailscale proxy image injected into pods to provide tailnet connectivity

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://tailscale.com/kb/1236/kubernetes-operator/](https://tailscale.com/kb/1236/kubernetes-operator/)

## About Tailscale Operator

The Tailscale Kubernetes Operator makes it easy to securely expose Kubernetes Services on a Tailscale network (tailnet)
and to connect pods to other resources on your tailnet. It supports:

- **Ingress**: expose cluster Services as Tailscale nodes so tailnet users can reach them without a public load balancer
- **Egress**: give pods a Tailscale identity so they can reach external tailnet resources
- **Subnet routers**: advertise cluster IP ranges to the tailnet
- **API server proxy**: secure kubectl access via Tailscale without exposing the Kubernetes API server publicly

For more details, visit
[https://tailscale.com/kb/1236/kubernetes-operator/](https://tailscale.com/kb/1236/kubernetes-operator/).

## About Tailscale

Tailscale is a mesh VPN (Virtual Private Network) service that streamlines connecting devices and services securely
across different networks. It enables encrypted point-to-point connections using the open source WireGuard protocol,
which means only devices on your private network can communicate with each other.

Unlike traditional VPNs, which tunnel all network traffic through a central gateway server, Tailscale creates a
peer-to-peer mesh network (known as a tailnet). However, you can still use Tailscale like a traditional VPN by routing
all traffic through an exit node.

For more details, visit
[https://tailscale.com/kb/1151/what-is-tailscale](https://tailscale.com/kb/1151/what-is-tailscale).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Tailscale is a trademark of Tailscale Inc. All rights in the mark are reserved to Tailscale Inc. Any use by Docker is
for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
