## About Consul Dataplane

Consul Dataplane (`consul-dataplane`) is the lightweight process that runs beside each workload in a HashiCorp Consul
service mesh. It connects to the Consul servers over gRPC, fetches the proxy's configuration, and starts and configures
an Envoy proxy that carries the workload's mesh traffic, so no Consul client agent is needed on the node. It also runs
mesh, ingress, terminating and API gateways, and a DNS proxy that answers Consul DNS queries.

The image ships `consul-dataplane`, Envoy, and `discover`, which finds Consul servers through cloud auto-join. It is
deployed by the official `hashicorp/consul` Helm chart. For more details, see
https://developer.hashicorp.com/consul/docs/architecture/control-plane/dataplane.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

HashiCorp and Consul are trademarks of HashiCorp, Inc. Envoy is a registered trademark of The Linux Foundation. All
rights in these marks are reserved to their owners. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.
