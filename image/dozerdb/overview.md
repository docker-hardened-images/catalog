## About DozerDB

DozerDB extends Neo4j Community Edition with open source graph database features through a bootstrapping plugin. This
image packages DozerDB 5.26.27.0, which is based on Neo4j Community Edition 5.26.27 and runs on Java 21.

For more information, visit https://dozerdb.org/ and the upstream organization at https://github.com/DozerDB.

### Build provenance boundary

DozerDB does not publish a source tag or commit that maps exactly to the 5.26.27.0 plugin and distribution. To avoid
claiming source provenance that cannot be verified, this image uses the upstream full distribution at
`https://dist.dozerdb.org/dozerdb-5.26.27.0-unix.tar.gz`, pinned to SHA-256
`19888fc3f658fe69640ac3f90ad9c1177a50ae5f03fbf6c1835438ffe770264e`, as its reproducibility boundary.

The Neo4j-compatible container entrypoint, utilities, and plugin registry come from the Neo4j 5.26.27 Docker publishing
sources pinned at commit `3e584bcdacb6b8f64729dd4a4850f4b06a605238`. The entrypoint is changed only to use the pinned DHI `gosu` artifact in
place of `su-exec`.

## About Docker Hardened Images

Docker Hardened Images are built to meet high security and compliance standards. They provide a trusted foundation for
containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images include signed provenance and a complete Software Bill of Materials (SBOM) and VEX metadata. They are
designed to secure your software supply chain while fitting into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
