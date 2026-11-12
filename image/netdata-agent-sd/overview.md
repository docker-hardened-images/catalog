## About Netdata Agent SD

Netdata Agent SD is a Kubernetes service discovery component for the Netdata monitoring agent. It watches the Kubernetes
API server for Pod and Service events and automatically generates data collection configurations for Netdata's
`go.d.plugin`. It runs as a sidecar or companion container alongside the Netdata agent in Kubernetes environments.

Common use cases include automatic discovery of monitored services in Kubernetes clusters, dynamic configuration
generation for Netdata collectors, and tag-based filtering and routing of discovered targets.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
