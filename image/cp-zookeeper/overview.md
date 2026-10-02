## About Confluent Platform ZooKeeper

Apache ZooKeeper is a coordination service. A Kafka cluster running in ZooKeeper mode uses it to store broker metadata,
elect a controller, and track topics and partitions. This image packages Apache ZooKeeper the way Confluent Platform
packages it: started by Confluent's container scripts and configured through `ZOOKEEPER_*` environment variables.

Confluent Platform deprecated ZooKeeper-based metadata management in 7.5 and removed it in 8.0, replacing it with KRaft.
Use this image for a cluster that has not moved to KRaft yet. For more information, see the
[Apache ZooKeeper project](https://zookeeper.apache.org/) and the
[Confluent Platform Docker documentation](https://docs.confluent.io/platform/7.9/installation/docker/index.html).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Apache ZooKeeper™ is a trademark of The Apache Software Foundation. All rights in the mark are reserved to The Apache
Software Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement,
or affiliation.

Confluent® and Confluent Platform™ are trademarks of Confluent, Inc. All rights in the marks are reserved to Confluent,
Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
