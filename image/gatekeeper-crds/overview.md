## About Gatekeeper CRDs

Gatekeeper CRDs packages the Custom Resource Definitions (CRDs) required by OPA Gatekeeper, an admission controller that
enforces policies on Kubernetes clusters using the Open Policy Agent (OPA) framework. This image also includes kubectl
for deploying the CRDs to a cluster.

Gatekeeper uses CRDs such as `ConstraintTemplate` and `Config` to let administrators define and enforce custom policies
across Kubernetes resources. By installing these CRDs separately, cluster operators can manage policy definitions
independently of the Gatekeeper controller lifecycle.

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
