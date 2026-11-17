## About VictoriaMetrics VMInsert

VictoriaMetrics VMInsert is a component of the VictoriaMetrics monitoring stack. Its primary function is to accepts the
ingested data and spreads it among vmstorage nodes according to consistent hashing over metric name and all its labels.
VMInsert supports high availability by allowing multiple vmstorage nodes to store the same data. It is designed to
handle high-throughput data ingestion efficiently.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

VictoriaMetrics® is a trademark of VictoriaMetrics Inc. All rights in the mark are reserved to VictoriaMetrics Inc. Any
use by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
