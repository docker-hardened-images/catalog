## About Consul K8s Control Plane

Consul K8s Control Plane (`consul-k8s-control-plane`) is the control plane binary for HashiCorp Consul on Kubernetes: it
runs the connect-inject webhook that adds Consul service mesh init containers to pods, the controllers that manage
Consul configuration entries and gateways, and the jobs that bootstrap ACLs and TLS. The image also ships the
`consul-cni` CNI plugin and `discover`, which finds Consul servers through cloud auto-join.

It is deployed through the official `hashicorp/consul` Helm chart. For more details, see
https://developer.hashicorp.com/consul/docs/k8s.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

HashiCorp and Consul are trademarks of HashiCorp, Inc. This listing is prepared by Docker. All third-party product
names, logos, and trademarks are the property of their respective owners and are used solely for identification. Docker
claims no interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
