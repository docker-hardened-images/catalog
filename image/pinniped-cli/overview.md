## About Pinniped CLI

The Pinniped CLI is the command-line interface for Pinniped, a Kubernetes authentication service that enables users to
authenticate to Kubernetes clusters using external identity providers. Pinniped provides a unified authentication
experience across multiple clusters, supporting both OIDC (OpenID Connect) and LDAP/Active Directory authentication.

The Pinniped CLI provides:

- **OIDC Authentication**: Authenticate to Kubernetes clusters using OpenID Connect providers like Okta, Google, Azure
  AD, and others
- **LDAP/AD Support**: Connect to clusters using enterprise LDAP or Active Directory credentials
- **Kubeconfig Generation**: Automatically generate and update kubeconfig files with valid credentials
- **Multi-Cluster Support**: Manage authentication across multiple Kubernetes clusters from a single CLI
- **Token Management**: Handle credential refresh and token lifecycle automatically

This CLI tool is used by end users to authenticate to Kubernetes clusters that have been configured with Pinniped. It
works seamlessly with kubectl and other Kubernetes tools by managing the authentication flow and credential storage in
your kubeconfig file.

For more details, visit:

- https://pinniped.dev/

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
sponsorship, or endorsement is implied. VMware is a trademark of VMware LLC. and is registered in the U.S. and numerous
other countries.
