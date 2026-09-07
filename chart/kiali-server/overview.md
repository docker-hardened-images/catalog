## About this Helm chart

This is a Kiali Server Docker Hardened Helm chart built from the official upstream Kiali Server Helm chart and using a
hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/kiali`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/kiali/helm-charts/tree/master/kiali-server](https://github.com/kiali/helm-charts/tree/master/kiali-server)

### About Kiali Server

Kiali is an open source project that provides observability for the Istio service mesh. It offers a web-based console to
visualize the mesh's topology, health, and traffic flow, and it validates Istio configuration to help catch
misconfigurations before they cause problems.

Kiali is particularly useful for operators and developers working with Istio, giving them insight into
service-to-service communication, request rates, latencies, and error rates, as well as tools for tracing requests
across the mesh.

For more information, visit the official website: https://kiali.io

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Kiali® and Istio® are trademarks of their respective owners. Any use by Docker is for referential purposes only and does
not indicate sponsorship, endorsement, or affiliation.
