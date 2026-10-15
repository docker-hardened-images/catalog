## About RisingWave

[RisingWave](https://risingwave.com/) is an open-source distributed SQL streaming database. It uses PostgreSQL-compatible SQL to ingest, process, and serve continuously changing data. It supports materialized views, stream processing, batch queries, and connectors for external data systems.

This image includes the RisingWave 3.1.0 all-in-one distribution. The distribution contains the native RisingWave executable and the Java connector libraries. It also includes the ADBC Snowflake driver that the upstream container image installs.

The runtime image runs as the `nonroot` user with UID and GID `65532`. The development image keeps this account but runs as `root`. The development image includes a shell, a package manager, and common diagnostic tools.

## Build provenance boundary

RisingWave publishes architecture-specific all-in-one release archives for Linux. This image uses the checksum-pinned v3.1.0 assets and verifies each asset with the SHA-256 digest that GitHub publishes. The image also uses the immutable ADBC Snowflake 1.12.0 release assets that the upstream v3.1.0 Dockerfile installs.

## About Docker Hardened Images

Docker Hardened Images are minimal images with secure defaults. They include vulnerability remediation, an SBOM, and build provenance. The RisingWave runtime image contains only the operating system packages that are required to run the upstream release distribution.

## Trademarks

RisingWave and its logo are the property of RisingWave Labs. This image is not affiliated with or endorsed by RisingWave Labs.
