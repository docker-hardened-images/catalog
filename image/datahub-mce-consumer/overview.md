## About DataHub MCE Consumer

DataHub MCE Consumer (Metadata Change Event Consumer) is the Kafka consumer service that processes
`MetadataChangeProposal_v1` events emitted by upstream producers (the ingestion CLI, the actions framework, and other
metadata sources) and applies them to DataHub's metadata storage layer via the GMS (General Metadata Service) API.
Successfully applied proposals are forwarded to the downstream `MetadataChangeLog_v1` topic that the MAE Consumer
subscribes to; failed proposals are written back to the `FailedMetadataChangeProposal_v1` topic so producers can retry.
The MCE Consumer is a Spring Boot 3.5.14 application built on OpenJDK 17. It can run standalone (this image's default)
or be embedded inside `datahub-gms`; standalone deployment gives operators independent scaling and isolated failure
domains for the metadata-write path.

For more information about DataHub, visit https://datahub.com.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

All third-party product names, logos, and trademarks are the property of their respective owners and are used solely for
identification. Docker claims no interest in those marks, and no affiliation, sponsorship, or endorsement is implied.
