## About AuthService

AuthService is an implementation of the [Envoy](https://envoyproxy.io) External Authorization gRPC filter that adds
OIDC/OAuth2 authentication to an [Istio](https://istio.io) service mesh, moving token acquisition out of application
code and into the mesh itself. Deployed at the sidecar or gateway level, it provides transparent login and logout,
session management with configurable timeouts, automatic token refresh, support for multiple OIDC providers, and trust
of custom CA certificates when talking to identity providers.

For more details, see https://github.com/istio-ecosystem/authservice.

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

Envoy® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
