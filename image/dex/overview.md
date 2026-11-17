## About Dex

Dex is an OpenID Connect (OIDC) identity service that acts as a portal to other identity providers through pluggable
connectors. It enables applications to defer authentication to external identity providers like LDAP, SAML, GitHub,
Google, Microsoft, and many others. Dex provides a unified authentication mechanism for applications without requiring
them to implement specific authentication protocols for each identity provider.

Dex is particularly useful in Kubernetes environments where it can provide flexible user authentication and access
control. By integrating with Kubernetes' OIDC authentication, Dex allows organizations to manage cluster access using
their existing identity infrastructure, providing username and group claims that work with authorization plugins like
RBAC.

For more information, visit the official website: https://dexidp.io/

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Dex™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
