## About Datadog Operator

The Datadog Operator is a Kubernetes operator that automates the deployment and lifecycle management of Datadog Agents
on Kubernetes clusters. It uses the `DatadogAgent` custom resource (v2alpha1) to validate agent configuration, reconcile
agent resources, and report configuration status back through the Kubernetes API. Common features enabled by default
include the Cluster Agent, Admission Controller, Kubernetes Event Collection, Kubernetes State Core Check, and
Orchestrator Explorer.

For full configuration reference and getting-started guides, see the
[upstream documentation](https://github.com/DataDog/datadog-operator).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Datadog® is a registered trademark of Datadog, Inc. All rights in the mark are reserved to Datadog, Inc. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
