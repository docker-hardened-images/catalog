## About Kubernetes Ingress Default Backend

Kubernetes Ingress Default Backend is a small HTTP server historically used by Kubernetes ingress deployments to handle
unmatched requests. It returns `default backend - 404` with HTTP 404 for application traffic, and exposes a health
endpoint for probes.

This image is source-built from the Kubernetes ingress-gce 404-server source, where the default backend component is
currently maintained.

For more details, visit https://github.com/kubernetes/ingress-gce/tree/v1.40.5/cmd/404-server.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Kubernetes® is a trademark of The Linux Foundation. This listing is prepared by Docker. All third-party product names,
logos, and trademarks are the property of their respective owners and are used solely for identification. Docker claims
no interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
