## About Open Policy Agent Envoy

Open Policy Agent Envoy (OPA-Envoy) extends Open Policy Agent (OPA) with a gRPC server that implements the Envoy
External Authorization API. Envoy, or a service mesh built on it, asks OPA-Envoy whether to allow each request, and
OPA-Envoy answers from your Rego policies, so you can enforce context-aware access control without modifying your
microservices.

For more details, visit https://www.openpolicyagent.org/docs/envoy.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Open Policy Agent (OPA)™ is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux
Foundation. Envoy® is a trademark of the Linux Foundation. Any use by Docker is for referential purposes only and does
not indicate sponsorship, endorsement, or affiliation.
