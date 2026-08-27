## About this Helm chart

This is an OpenCost Helm chart built from the upstream OpenCost Helm chart and using a hardened configuration with
Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/opencost`
- `dhi/opencost-ui`
- `dhi/aws-sigv4-proxy`
- `dhi/curl`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/opencost/opencost-helm-chart](https://github.com/opencost/opencost-helm-chart)

## About OpenCost

OpenCost is a Kubernetes-native cost monitoring and allocation tool. It provides real-time visibility into
infrastructure and container costs, enabling teams to track spending by namespace, deployment, label, and more. OpenCost
is a CNCF Sandbox project and implements the OpenCost Specification for cloud cost attribution.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

OpenCost® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
