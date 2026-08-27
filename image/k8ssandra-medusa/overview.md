## About K8ssandra Medusa

K8ssandra Medusa is an Apache Cassandra backup and restore tool designed for cloud-native environments. It provides
reliable backup, restore, and verification capabilities for Cassandra clusters running in Kubernetes, with support for
S3, GCS, Azure, and S3-compatible object stores. Medusa is part of the K8ssandra project: it is normally deployed as a
sidecar alongside Cassandra pods by the `k8ssandra-operator`, and backup or restore operations are driven through
`MedusaBackupJob`, `MedusaBackupSchedule`, and `MedusaRestoreJob` custom resources rather than by invoking the CLI
directly.

Key capabilities:

- Full and differential (incremental) backups of Cassandra data
- Cluster-wide and per-node backup and restore
- Backup verification and integrity checks
- Pluggable object-storage backends (S3, GCS, Azure, S3-compatible)
- gRPC service used by `k8ssandra-operator` to coordinate backups and restores

For more information, visit the [Medusa documentation](https://docs.k8ssandra.io/components/medusa/) and the
[cassandra-medusa GitHub repository](https://github.com/thelastpickle/cassandra-medusa).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Apache Cassandra is a trademark of the Apache Software Foundation. K8ssandra is a trademark of the K8ssandra project.
This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
