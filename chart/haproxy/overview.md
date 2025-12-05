## About this Helm chart

This is an HAProxy Docker Hardened Helm chart built from the upstream HAProxy Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/haproxy`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/haproxytech/helm-charts/tree/main/haproxy](https://github.com/haproxytech/helm-charts/tree/main/haproxy)

### About HAProxy

HAProxy is a free, open source high availability solution, providing load balancing and proxying for TCP and HTTP-based
applications by spreading requests across multiple servers. It is written in C and has a reputation for being fast and
efficient (in terms of processor and memory usage).

For more details, visit https://docs.haproxy.org/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

HAProxy® is a registered trademark in the U.S and France of HAProxy Technologies LLC and its affiliated entities. All
rights in the mark are reserved to HAProxy Technologies LLC. Any use by Docker is for referential purposes only and does
not indicate sponsorship, endorsement, or affiliation.
