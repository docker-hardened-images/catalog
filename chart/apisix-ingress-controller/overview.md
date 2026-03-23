## About this Helm chart

This is an APISIX Ingress Controller Helm chart built from the upstream APISIX Ingress Controller Helm chart and using a
hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/apisix-ingress-controller`
- `dhi/adc`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/apache/apisix-helm-chart/blob/master/charts/apisix-ingress-controller/README.md](https://github.com/apache/apisix-helm-chart/blob/master/charts/apisix-ingress-controller/README.md)

## About APISIX Ingress Controller

The APISIX Ingress Controller allows you to run the APISIX Gateway as a Kubernetes Ingress to handle inbound traffic for
a Kubernetes cluster. It dynamically configures and manages the APISIX Gateway using Gateway API resources.

For more information about APISIX Ingress Controller, visit the upstream documentation at
https://github.com/apache/apisix-ingress-controller/tree/master/docs/en/latest/getting-started.

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
