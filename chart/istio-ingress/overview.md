## About this Helm chart

This is an Istio Ingress Gateway Docker Hardened Helm chart built from the upstream Istio
[istio-ingress](https://github.com/istio/istio/tree/master/manifests/charts/gateways/istio-ingress) Helm chart and using
a hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/istio-proxyv2` (Envoy proxy)

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://istio.io/latest/](https://istio.io/latest/)

### About Istio Ingress Gateway

The Istio Ingress Gateway is an Envoy proxy deployed at the edge of the mesh that handles incoming traffic. It allows
you to define entry points into the mesh using `Gateway` and `VirtualService` resources, providing fine-grained control
over routing, TLS termination, and traffic management for inbound requests.

For more details, visit https://istio.io/latest/docs/tasks/traffic-management/ingress/ingress-control/.

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
