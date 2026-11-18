## About Confluent Schema Registry

Confluent Schema Registry provides a RESTful interface for storing and retrieving Avro, JSON Schema and Protobuf schemas
for Apache Kafka. It keeps a versioned history of every subject, checks new schemas against configurable compatibility
rules, and stores its state in a Kafka topic. This image packages Schema Registry the way Confluent Platform does:
started by Confluent's container scripts and configured through `SCHEMA_REGISTRY_*` environment variables.

Schema Registry is built from the Confluent source at the release tag. The image also carries the Avro, JSON Schema and
Protobuf console producers and consumers and the data encryption key tools that ship with it. Confluent's licensed
Schema Linking, security and telemetry jars are not included; the guides explain how to mount them from Confluent's
image if your license covers them. For more information, see the
[Schema Registry documentation](https://docs.confluent.io/platform/current/schema-registry/index.html) and the
[Confluent Platform Docker documentation](https://docs.confluent.io/platform/current/installation/docker/index.html).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Confluent, Confluent Platform and Schema Registry are trademarks or service marks of Confluent, Inc. All rights in the
marks are reserved to Confluent, Inc. Any use by Docker is for referential purposes only and does not indicate
sponsorship, endorsement, or affiliation.

Apache Kafka® is a registered trademark of The Apache Software Foundation. All rights in the mark are reserved to The
Apache Software Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
