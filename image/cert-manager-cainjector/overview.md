## About cert-manager-cainjector

cert-manager-cainjector is a Kubernetes addon component that automates the injection of CA (Certificate Authority) data
into webhooks and APIServices from cert-manager certificates. As part of the cert-manager ecosystem, the CA injector
ensures that Kubernetes admission webhooks, CustomResourceDefinition conversion webhooks, and extension API servers
always have the correct CA bundle data for proper certificate validation.

The CA injector populates the caBundle field of `ValidatingWebhookConfiguration`, `MutatingWebhookConfiguration`,
`CustomResourceDefinition`, and `APIService` resources by copying CA data from cert-manager Certificates, Kubernetes
Secrets, or the Kubernetes API server's CA certificate. This automation eliminates the need for manual CA bundle
management and enables secure communication between the Kubernetes API server and webhook servers.

For more details, visit https://cert-manager.io/docs/concepts/ca-injector/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Cert Manager™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
