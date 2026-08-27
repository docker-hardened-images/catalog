## About Tailscale

Tailscale is a mesh VPN (Virtual Private Network) service that streamlines connecting devices and services securely
across different networks. It enables encrypted point-to-point connections using the open source WireGuard protocol,
which means only devices on your private network can communicate with each other.

Unlike traditional VPNs, which tunnel all network traffic through a central gateway server, Tailscale creates a
peer-to-peer mesh network (known as a tailnet). However, you can still use Tailscale like a traditional VPN by routing
all traffic through an exit node.

For more details, visit
[https://tailscale.com/kb/1151/what-is-tailscale](https://tailscale.com/kb/1151/what-is-tailscale)

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
