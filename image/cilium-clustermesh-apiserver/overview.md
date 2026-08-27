### About Cilium Clustermesh API Server

Cilium is a networking, observability, and security solution with an eBPF-based dataplane. It provides a simple flat
Layer 3 network with the ability to span multiple clusters in either a native routing or overlay mode. It is L7-protocol
aware and can enforce network policies on L3-L7 using an identity based security model that is decoupled from network
addressing.

Cilium Cluster Mesh connects multiple Kubernetes clusters, allowing pods in one cluster to access services in others, as
long as all clusters use Cilium as their CNI. This is achieved by deploying a clustermesh-apiserver to sync shared state
across clusters.

Multi-Cluster Service Discovery: Enables services in one cluster to discover and connect to services running in other
clusters, creating a unified service mesh across cluster boundaries Cross-Cluster Load Balancing: Distributes traffic
across service endpoints that span multiple clusters, providing high availability and optimal resource utilization
Shared Identity Management: Synchronizes security identities across clusters, ensuring consistent network policy
enforcement in multi-cluster scenarios Secure Communication: Establishes secure, encrypted communication channels
between clusters using mutual TLS authentication Service Export/Import: Manages which services are exported from each
cluster and which remote services are imported for local consumption The ClusterMesh API Server is deployed as a
LoadBalancer service in each participating cluster, enabling Cilium agents across clusters to establish secure
connections and exchange routing information. This creates a transparent, scalable solution for multi-cluster
deployments without requiring complex VPN setups or network overlays.

For more details, see https://cilium.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Cilium® is a registered trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
