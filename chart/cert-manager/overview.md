## About this Helm chart

This is a cert-manager Docker Helm chart built from the upstream cert-manager Helm chart and using a hardened
configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/cert-manager-controller`
- `dhi/cert-manager-cainjector`
- `dhi/cert-manager-webhook`
- `dhi/cert-manager-acmesolver`
- `dhi/cert-manager-startupapicheck`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager](https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager)

### About cert-manager

cert-manager adds certificates and certificate issuers as resource types in Kubernetes clusters, and simplifies the
process of obtaining, renewing and using those certificates.

It supports issuing certificates from a variety of sources, including Let's Encrypt (ACME), HashiCorp Vault, and Venafi
TPP / TLS Protect Cloud, as well as local in-cluster issuance.

cert-manager also ensures certificates remain valid and up to date, attempting to renew certificates at an appropriate
time before expiry to reduce the risk of outages and remove toil.

For more information and documentation see https://cert-manager.io/.

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
