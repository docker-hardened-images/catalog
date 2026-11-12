## About Klipper Service Load Balancer

Klipper Load Balancer is a service load balancer implementation for K3s, the lightweight Kubernetes distribution by
Rancher. It enables services of type `LoadBalancer` to work in K3s clusters without requiring an external cloud provider
by binding to host ports on the cluster nodes. This makes it straightforward to expose services externally in
on-premises or edge environments where cloud load balancers are not available.

For more details, see https://github.com/k3s-io/klipper-lb.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

K3s is a CNCF Sandbox project. RKE2 is associated with SUSE Rancher. This listing is prepared by Docker. All third-party
product names, logos, and trademarks are the property of their respective owners and are used solely for identification.
Docker claims no interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
