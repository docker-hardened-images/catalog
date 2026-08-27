## About vault-k8s

vault-k8s is HashiCorp's official Kubernetes integration that provides seamless secret management for containerized
applications. It operates as a mutating admission webhook that automatically injects Vault Agent containers into
Kubernetes pods, enabling applications to access HashiCorp Vault secrets without requiring code changes or direct Vault
API knowledge.

The system works by intercepting pod creation events, examining pod annotations to determine secret requirements, and
then modifying pod specifications to include Vault Agent init and sidecar containers that authenticate with Vault,
retrieve secrets, and render them to shared volumes accessible by application containers.

This approach allows organizations to centralize secret management through Vault while maintaining the simplicity and
security of Kubernetes deployments, supporting use cases like legacy application modernization, automated secret
rotation, and compliance requirements across development and production environments.

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
