## About Cilium DNS Proxy

The Cilium Standalone DNS Proxy (`standalone-dns-proxy`) is an alpha component of the [Cilium](https://cilium.io)
networking project that provides independent DNS proxying capabilities. It runs as a separate DaemonSet, receives DNS
policy rules from the Cilium agent via gRPC, and reports DNS query results back for policy enforcement — offloading DNS
proxy work from the main Cilium agent process.

> **Note:** The standalone DNS proxy binary was introduced as a separate component in Cilium v1.19. This image is
> supported from **v1.19 and later**.

For more details, visit
[https://docs.cilium.io/en/stable/security/standalone-dns-proxy/](https://docs.cilium.io/en/stable/security/standalone-dns-proxy/).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Cilium® is a trademark of The Linux Foundation. All rights in the mark are reserved to The Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
