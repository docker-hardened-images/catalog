## About this Helm chart

This is a Vector Docker Hardened Helm chart built from the upstream Vector Helm chart and using a hardened configuration
with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/vector`
- `dhi/haproxy`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/vectordotdev/helm-charts](https://github.com/vectordotdev/helm-charts)

### About Vector

Vector is a high-performance, end-to-end observability data pipeline that enables you to collect, transform, and route
logs, metrics, and traces. With Vector's flexible topology and configuration, you can build reliable data pipelines that
fit your specific observability needs. Vector supports numerous sources and sinks, including Prometheus, Kafka, AWS S3,
Elasticsearch, and many others, making it easy to integrate into existing infrastructure.

For more details, visit https://vector.dev/docs/.

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
