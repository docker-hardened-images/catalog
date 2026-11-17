## About Milvus etcd

Milvus etcd (milvus-etcd) is the [etcd](https://etcd.io) distribution maintained by the [Milvus](https://milvus.io)
project as the metadata store for Milvus vector database deployments. It packages the official etcd server and client
tools together with Bitnami-compatible startup scripts, so the container renders its etcd configuration from environment
variables and works as the drop-in `etcd` image consumed by the [milvus-helm](https://github.com/zilliztech/milvus-helm)
chart.

For more details, see https://github.com/milvus-io/bitnami-docker-etcd.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

etcd® is a trademark of the Linux Foundation. All rights in the mark are reserved to the Linux Foundation. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.

Milvus is a graduated project of the LF AI & Data Foundation. Milvus® is a registered trademark of LF Projects, LLC. All
rights in the mark are reserved to LF Projects, LLC. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.

All other third-party names, product names, and logos mentioned are the property of their respective owners. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
