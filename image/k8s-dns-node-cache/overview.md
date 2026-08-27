## About NodeLocal DNS Cache

NodeLocal DNS Cache is a Kubernetes component that runs a per-node DNS cache to improve cluster DNS performance and
reduce load on cluster DNS services. It wraps CoreDNS with node-local networking setup, including iptables rules and a
local listening address.

This hardened image is built from the official [kubernetes/dns](https://github.com/kubernetes/dns) source and is
intended for NodeLocal DNSCache DaemonSet deployments.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. CoreDNS is a CNCF graduated project. This listing is
prepared by Docker. All third-party product names, logos, and trademarks are the property of their respective owners and
are used solely for identification. Docker claims no interest in those marks, and no affiliation, sponsorship, or
endorsement is implied.
