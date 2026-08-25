## About this Helm chart

This is a Valkey Operator Docker Helm chart built from the upstream Valkey Operator Helm chart implementation using a
hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/valkey-operator`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/valkey-io/valkey-helm/tree/main/valkey-operator](https://github.com/valkey-io/valkey-helm/tree/main/valkey-operator)

### About the Valkey Operator

The Valkey Operator is a Kubernetes operator that automates the deployment, scaling, and lifecycle management of Valkey
clusters running on Kubernetes. It watches Valkey custom resources and reconciles Deployments, StatefulSets, and
Services so operators do not need to manage Valkey infrastructure by hand.

For more details, visit https://valkey.io

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Valkey and the Valkey logo are trademarks of LF Projects, LLC. All rights in the mark are reserved to LF Projects, LLC.
Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
