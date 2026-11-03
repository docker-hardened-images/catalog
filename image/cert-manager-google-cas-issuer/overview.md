## About Google CAS Issuer for cert-manager

Google CAS Issuer is an external issuer for cert-manager that signs certificate requests with Google Cloud Certificate
Authority Service (CAS). It adds the `GoogleCASIssuer` and `GoogleCASClusterIssuer` resources, which point cert-manager
at a CAS certificate authority pool.

Use it when certificates for Kubernetes workloads must come from a private CA managed in Google Cloud. The project is
documented at https://github.com/cert-manager/google-cas-issuer.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Cert Manager™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation. Google
Cloud™ is a trademark of Google LLC. All rights in the mark are reserved to Google LLC. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
