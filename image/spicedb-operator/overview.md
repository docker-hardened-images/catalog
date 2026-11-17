## About SpiceDB Operator

SpiceDB Operator is a Kubernetes operator that manages the lifecycle of [SpiceDB](https://github.com/authzed/spicedb)
authorization database instances. It watches for `SpiceDBCluster` custom resources and handles provisioning,
configuration, upgrades, and health management of SpiceDB deployments. Version migrations follow an update graph that
defines valid upgrade paths between SpiceDB releases, preventing unsafe skips.

Official documentation: https://github.com/authzed/spicedb-operator

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

SpiceDB is a trademark of AuthZed, Inc. All rights in the mark are reserved to AuthZed, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
