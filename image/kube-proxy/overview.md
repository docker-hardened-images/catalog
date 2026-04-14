## About kube-proxy

kube-proxy implements Kubernetes Service networking on each node. It watches Service and EndpointSlice objects and
programs the node’s packet forwarding rules (for example via iptables, IPVS, or nftables depending on configuration) to
provide virtual IPs and load balancing to Pods.

Use this image when you need a hardened, minimal container image for running kube-proxy on Kubernetes nodes.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes® is a registered trademark of The Linux Foundation. Any use by Docker is for referential purposes only and
does not indicate sponsorship, endorsement, or affiliation.
