## About KServe Agent

KServe Agent is a lightweight sidecar proxy component that enhances machine learning model serving within Kubernetes
environments. It runs alongside your model server container and provides advanced serving capabilities including request
batching, model pulling, and observability features.

The agent operates as a transparent proxy that receives client requests, processes them through configurable middleware
for batching and logging, and forwards them to your model server. This architecture enables you to add production-ready
serving features to any model server without requiring code changes.

For more information about KServe, visit the upstream documentation at https://kserve.github.io/website/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
