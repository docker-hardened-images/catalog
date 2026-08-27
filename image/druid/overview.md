## About Apache Druid

Apache Druid is a high-performance real-time analytics database built for sub-second queries on large-scale event data.
It is designed for OLAP workloads where data is ingested from streaming sources (Kafka, Kinesis) or batch sources (S3,
HDFS) and immediately available for interactive queries. Druid's distributed architecture separates ingestion, storage,
and query concerns across dedicated process types - Coordinator, Broker, Historical, MiddleManager, and Router - which
can be scaled independently to match workload characteristics.

For more details, see https://druid.apache.org/docs/latest/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Apache Druid® is a trademark of the Apache Software Foundation. All rights in the mark are reserved to the Apache
Software Foundation. Any use by Docker is for referential purposes only and does not indicate sponsorship, endorsement,
or affiliation.
