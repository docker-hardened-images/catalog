## About DataHub MAE Consumer

DataHub MAE Consumer (Metadata Audit Event Consumer) is the Kafka consumer service responsible for ingesting
MetadataChangeLog events into DataHub's search and graph indices. It subscribes to the `MetadataChangeLog_Versioned_v1`
and `MetadataChangeLog_Timeseries_v1` topics produced by the DataHub GMS (General Metadata Service) and writes the
parsed events into Elasticsearch or OpenSearch for full-text search and, optionally, into Neo4j for graph-based lineage
traversal. When `PE_CONSUMER_ENABLED=true`, it also processes the `PlatformEvent_v1` topic. The MAE Consumer is a Spring
Boot application built on OpenJDK 17 and is a required backend component of every DataHub deployment.

For more information about DataHub, visit https://datahub.com.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

DataHub™ is a trademark of the DataHub Project (https://github.com/datahub-project), maintained by Acryl Data, Inc. All
rights in the mark are reserved to their respective owners. Any use by Docker is for referential purposes only and does
not indicate sponsorship, endorsement, or affiliation.
