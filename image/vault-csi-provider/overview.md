## About vault-csi-provider

`vault-csi-provider` is HashiCorp's official Kubernetes integration that enables secure, file-based access to Vault
secrets through the Container Storage Interface (CSI). It operates as a provider plugin for the Secrets Store CSI
driver, allowing Kubernetes pods to mount secrets from HashiCorp Vault directly as files in their filesystem without
requiring code changes or embedded credentials in container images.

The system works by intercepting pod mount requests through SecretProviderClass resources, authenticating with Vault
using Kubernetes service account tokens, and dynamically retrieving secrets that are then mounted as files within pod
containers. This approach supports various Vault secret engines including key-value stores, dynamic database
credentials, PKI certificates, and custom secret backends, while maintaining secure authentication through Vault's
Kubernetes auth method.

This integration allows organizations to centralize secret management through Vault while preserving Kubernetes-native
deployment patterns, supporting use cases like dynamic credential rotation, certificate lifecycle management, and
zero-trust application security across development and production environments without the overhead of sidecar
containers or init processes.

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
