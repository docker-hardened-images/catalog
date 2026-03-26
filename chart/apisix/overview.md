## About this Helm chart

This is an APISIX Helm chart built from the upstream APISIX Helm chart and using a hardened configuration with Docker
Hardened Images.

The following Docker Hardened Helm charts are used in this Helm chart:

- `dhi/apisix`
- `dhi/busybox`

The following Docker Hardened Images are used in this Helm chart:

- `dhi/apisix-ingress-controller-chart`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/apache/apisix-helm-chart/blob/master/docs/en/latest/apisix.md](https://github.com/apache/apisix-helm-chart/blob/master/docs/en/latest/apisix.md)

## About APISIX

Apache APISIX is a dynamic, real-time, high-performance API Gateway that provides rich traffic management features such
as load balancing, dynamic upstream, canary release, circuit breaking, authentication, observability, and more. You can
use APISIX to handle traditional north-south traffic, as well as east-west traffic between services, making it suitable
for microservices architectures and API management at scale.

For more details, visit https://apisix.apache.org/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Apache APISIX® is a trademark of the Apache Software Foundation. All rights in the mark are reserved to the Apache
Software Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement,
or affiliation.
