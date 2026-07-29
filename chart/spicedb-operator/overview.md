## About this Helm chart

This is a SpiceDB Operator Docker Hardened Helm chart built from the upstream SpiceDB Operator Helm chart and using a
hardened configuration with Docker Hardened Images.

The following Docker Hardened Images are used in this Helm chart:

- `dhi/spicedb-operator`
- `dhi/spicedb`

To learn more about how to use this Helm chart you can visit the upstream documentation:
[https://authzed.com/docs/spicedb/operator](https://authzed.com/docs/spicedb/operator)

## About SpiceDB Operator

The SpiceDB Operator is a Kubernetes operator that manages the lifecycle of SpiceDB clusters. It handles installation,
upgrades, and configuration of SpiceDB — an open-source, Zanzibar-inspired database for scalable fine-grained
authorization. The operator watches for `SpiceDBCluster` custom resources and reconciles the desired state, including
managing migrations, validating configuration, and ensuring high availability.

Official documentation: https://authzed.com/docs/spicedb/operator

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

SpiceDB® is a trademark of AuthZed Inc. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
