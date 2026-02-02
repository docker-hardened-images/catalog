## About this Helm chart

This is an OAuth2 Proxy Docker Helm chart built from the upstream OAuth2 Proxy Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/oauth2-proxy`
- `dhi/alpine-base`

To learn more about how to use this Helm chart you can visit the upstream documentation:
https://github.com/oauth2-proxy/manifests

### About OAuth2 Proxy

OAuth2 Proxy is a reverse proxy and static file server that provides authentication using OAuth2 and OpenID Connect
providers such as Google, GitHub, Azure, and others. It is commonly used to secure web applications and services by
acting as an authentication gateway, requiring users to authenticate before accessing upstream services.

OAuth2 Proxy supports a wide range of providers and is highly configurable via environment variables, command-line
flags, or a configuration file. It is suitable for use with Kubernetes, Docker, and other containerized environments.

For more details, visit https://github.com/oauth2-proxy/oauth2-proxy.

## Docker Hardened Images

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
