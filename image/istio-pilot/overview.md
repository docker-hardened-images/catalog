## About Istio Pilot

Istio Pilot is the core control plane component of the Istio service mesh, responsible for service discovery,
configuration management, and intelligent traffic management. Pilot acts as the brain of the mesh, continuously
communicating with Kubernetes API server and translating high-level Istio configuration into proxy configurations that
are pushed to all sidecar proxies and gateway proxies in the mesh.

Pilot handles the complex task of translating service mesh policies and routing rules into low-level proxy
configurations, ensuring consistent behavior across all proxies in the mesh. It maintains awareness of all services
running in the cluster and dynamically distributes their configuration to proxies as services scale up, down, or move
between nodes.

Key responsibilities of Istio Pilot:

- **Service Discovery**: Automatic detection and registration of services from Kubernetes
- **Configuration Distribution**: Pushes proxy configurations to all proxies in the mesh (sidecar and gateway)
- **Traffic Management**: Implements load balancing, circuit breaking, retries, and traffic splitting policies
- **Security Policy Enforcement**: Manages mutual TLS (mTLS) configuration and authorization policies
- **Certificate Rotation**: Manages and rotates short-lived certificates for mTLS connections
- **Dynamic Reconfiguration**: Updates proxy configurations in real-time as services and policies change
- **Service Mesh Observability**: Provides metrics and diagnostic information about mesh health
- **Multi-Cluster Coordination**: Handles service discovery and traffic management across multiple clusters
- **Virtual Service Processing**: Translates VirtualService CRDs into Envoy routing configurations
- **Destination Rule Processing**: Applies DestinationRule policies for load balancing and connection pooling

Pilot is a stateless component that scales horizontally and is typically deployed as a highly available deployment with
multiple replicas. It communicates with proxies using the xDS gRPC protocol, enabling real-time configuration updates
and efficient resource management.

For more information about Istio Pilot and control plane architecture, visit
https://istio.io/latest/docs/ops/deployment/architecture/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Istio® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
