## About Multus CNI

Multus CNI is a Container Network Interface (CNI) meta-plugin for Kubernetes that enables attaching multiple network
interfaces to a pod. By default, a Kubernetes pod has a single network interface (in addition to loopback); Multus acts
as a meta-plugin that calls other CNI plugins to attach additional interfaces, enabling multi-homed pods for use cases
such as network function virtualization (NFV) and telco workloads that require separate control, management, and data
plane networks.

Multus CNI follows the Kubernetes Network Custom Resource Definition De-facto Standard put forward by the Kubernetes
Network Plumbing Working Group (NPWG), and can be deployed in either a lightweight "thin plugin" mode or a client/server
"thick plugin" mode that adds features such as metrics.

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
