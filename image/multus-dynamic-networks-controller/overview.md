## About Multus Dynamic Networks Controller

The Multus Dynamic Networks Controller is a Kubernetes controller that enables hot-plugging and unplugging of network
interfaces on running pods. It works alongside [Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni) to watch
for changes to pod network annotations and dynamically attach or detach additional network interfaces without requiring
pod restarts. This is particularly useful for workloads such as telecommunications and network functions virtualization
(NFV) that require runtime network reconfiguration.

For more information, see the
[Multus Dynamic Networks Controller repository](https://github.com/k8snetworkplumbingwg/multus-dynamic-networks-controller).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kubernetes is a registered trademark of [The Linux Foundation](https://www.linuxfoundation.org/legal/trademarks). This
listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their respective
owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
