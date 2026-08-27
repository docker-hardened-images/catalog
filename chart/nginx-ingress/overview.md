## About this Helm chart

This is an NGINX Ingress Controller Helm chart built from the upstream NGINX Ingress Controller Helm chart and using a
hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/nginx-ingress`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/nginx/kubernetes-ingress/blob/main/charts/nginx-ingress/README.md](https://github.com/nginx/kubernetes-ingress/blob/main/charts/nginx-ingress/README.md)

## About NGINX Ingress Controller

NGINX Ingress Controller runs inside a Kubernetes cluster and configures NGINX based on Kubernetes Ingress resources and
(optionally) NGINX custom resources such as VirtualServer, VirtualServerRoute, and TransportServer.

Upstream documentation: https://docs.nginx.com/nginx-ingress-controller/

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

For F5 trademark usage (including NGINX), see: https://www.f5.com/company/policies/trademarks
