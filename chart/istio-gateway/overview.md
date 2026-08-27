## About this Helm chart

This is an Istio Gateway Docker Hardened Helm chart built from the upstream Istio
[istio-gateway](https://github.com/istio/istio/tree/master/manifests/charts/gateway) Helm chart and using a hardened
configuration with Docker Hardened Images.

This Helm chart uses `image: auto`, meaning the proxy image is not specified directly but is automatically injected by
the `dhi/istio-discovery` chart (istiod), which must be installed beforehand. The injected image is:

- `dhi/istio-proxyv2` (Envoy proxy)

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://istio.io/latest/](https://istio.io/latest/)

### About Istio Gateway

The Istio Gateway is an Envoy proxy deployed at the edge of the mesh that handles incoming and outgoing traffic. It
allows you to define entry points into the mesh using `Gateway` and `VirtualService` resources, providing fine-grained
control over routing, TLS termination, and traffic management.

For more details, visit https://istio.io/latest/docs/concepts/traffic-management/#gateways.

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
