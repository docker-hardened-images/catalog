## About DataHub Frontend

[DataHub](https://datahub.com) is an open-source metadata platform for data discovery, observability, and governance.
The DataHub Frontend image provides the web UI layer of the DataHub platform: a Play Framework 2.8 (Scala/Java 17)
server that bundles and serves the React/Vite/TypeScript single-page application. It is one component of a full DataHub
deployment and requires the DataHub GMS (Generalized Metadata Service) backend to function.

This image is typically deployed alongside `datahub-gms`, `datahub-actions`, and supporting infrastructure (Kafka,
Elasticsearch, MySQL/PostgreSQL). Users interact with the DataHub web UI on port 9002 to explore data assets, track data
lineage, manage metadata, and configure governance policies across the data stack.

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
