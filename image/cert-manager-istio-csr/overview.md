## About cert-manager-istio-csr

cert-manager-istio-csr is an agent that integrates cert-manager with Istio for certificate management in Kubernetes
clusters. It acts as a gRPC server that receives Certificate Signing Requests (CSRs) from the Istio control plane
(istiod) and uses cert-manager's CertificateRequest API to sign certificates. The agent also distributes CA bundles by
creating and updating `istio-ca-root-cert` ConfigMaps in all namespaces, ensuring Istio workloads can trust the
certificates issued by cert-manager.

cert-manager-istio-csr supports Istio v1.10+ and cert-manager v1.3+, providing a seamless integration between these two
popular Kubernetes projects. It exposes Prometheus metrics on port 9402 and provides health checks via a readiness probe
on port 6060, making it easy to monitor and integrate into existing Kubernetes deployments.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Istio® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
