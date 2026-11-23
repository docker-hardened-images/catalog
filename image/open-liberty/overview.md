## About Open Liberty

Open Liberty is a lightweight, open source Java application server for Jakarta EE and MicroProfile applications. It is
built from modular features, so a server loads only the capabilities that its `server.xml` configuration enables, which
keeps startup fast and memory use low for cloud-native microservices and traditional enterprise applications alike.

This image provides the full Open Liberty runtime on an Eclipse Temurin Java runtime. It keeps the upstream Open Liberty
image's directory layout and its server start, `configure.sh`, and health-check helper scripts, but omits the Liberty
InstantOn checkpoint and restore, OpenJ9 shared class cache, and Infinispan client setup helpers. For more information,
visit https://openliberty.io/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Open Liberty® is a registered trademark of International Business Machines Corporation. All rights in the mark are
reserved to International Business Machines Corporation. Any use by Docker is for referential purposes only and does not
indicate sponsorship, endorsement, or affiliation.
