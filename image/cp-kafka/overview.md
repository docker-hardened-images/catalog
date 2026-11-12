## About Confluent Platform Kafka

Apache Kafka is a distributed event streaming platform. This image packages Apache Kafka the way Confluent Platform
packages it: started by Confluent's container scripts and configured through `KAFKA_*` environment variables. The 7.9
tags are the last Confluent Platform line that supports ZooKeeper mode alongside KRaft; the 8.x tags are KRaft-only,
matching Confluent Platform's removal of ZooKeeper in 8.0.

The Kafka distribution inside comes from the hardened `kafka-3.9`/`kafka-4.3` packages, built from the same Apache
source as `dhi/kafka` and matching the Apache releases Confluent Platform builds on. For more information, see the
[Apache Kafka project](https://kafka.apache.org/) and the
[Confluent Platform Docker documentation](https://docs.confluent.io/platform/current/installation/docker/index.html).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Apache Kafka® is a registered trademark of The Apache Software Foundation. All rights in the mark are reserved to The
Apache Software Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.

Confluent and Confluent Platform are trademarks or service marks of Confluent, Inc. All rights in the marks are reserved
to Confluent, Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or
affiliation.
