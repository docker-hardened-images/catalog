## About KEDA HTTP Add-on Interceptor

The KEDA HTTP Add-on lets Kubernetes users scale their HTTP servers up and down, including to and from zero, based on
incoming HTTP traffic. The interceptor is the add-on's proxy: it receives the HTTP traffic, routes each request to the
backend Service its `InterceptorRoute` names, holds requests while a scaled-to-zero backend starts, and reports the
pending request counts the add-on's scaler hands to KEDA.

The interceptor runs alongside the add-on's operator and scaler, which the add-on's Helm chart deploys together. The
project is documented at https://keda.sh/http-add-on/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

KEDA is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation. Kubernetes is a
trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
