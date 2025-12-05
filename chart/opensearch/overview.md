## About this Helm chart

This is an OpenSearch Docker Helm chart built from the upstream OpenSearch Helm chart and using a hardened configuration
with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/opensearch`
- `dhi/busybox`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://github.com/opensearch-project/helm-charts](https://github.com/opensearch-project/helm-charts)

### About OpenSearch

OpenSearch is a distributed, RESTful search and analytics engine designed for a wide range of use cases, including log
analytics, real-time application monitoring, and search. As an open-source project, OpenSearch provides a secure,
high-performance platform for storing, searching, and analyzing large volumes of data.

For more information about OpenSearch, visit https://opensearch.org.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Amazon OpenSearch is a trademark of Amazon Web Services. All rights in the mark are reserved to Amazon Web Services. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
