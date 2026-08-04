## About this Helm chart

This is a Valkey Resources Docker Helm chart built from the upstream Valkey `valkey-resources` Helm chart using a
hardened configuration with Docker Hardened Images. This chart is image-less: it only creates an operator-managed
`ValkeyCluster` custom resource (and, optionally, a `PodMonitor`). There are no DHI images needed with this Helm chart.

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/valkey-io/valkey-helm/tree/main/valkey-resources](https://github.com/valkey-io/valkey-helm/tree/main/valkey-resources)

## About Valkey Resources

Valkey Resources deploys a single operator-managed `ValkeyCluster` custom resource. It does not install the
`valkey-operator` itself: the operator, and the `ValkeyCluster` custom resource definition (CRD) it registers, must
already be installed and running in the cluster. Without the operator, the Kubernetes API server rejects the
`ValkeyCluster` resource this chart creates.

For more details, visit https://valkey.io

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
