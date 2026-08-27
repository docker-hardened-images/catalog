## About Source Controller

The Flux CD Source Controller is a Kubernetes controller that acquires artifacts from external sources such as Git
repositories, Helm repositories, OCI registries, and S3-compatible object storage. It continuously reconciles the
desired source state by fetching, verifying, and serving artifacts to other Flux controllers via an embedded HTTP
server.

For more details, see https://fluxcd.io/flux/components/source/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Flux is a trademark of the Cloud Native Computing Foundation. All rights in the mark are reserved to the CNCF. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
