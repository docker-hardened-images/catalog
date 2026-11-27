## About Icinga DB

Icinga DB is the daemon that moves Icinga 2 monitoring data into a relational database. Icinga 2 publishes its
configuration, check results, state changes, and history to a Redis® server through its Icinga DB feature, and the
Icinga DB daemon synchronizes that data into MySQL, MariaDB, or PostgreSQL, where Icinga DB Web reads it. The upstream
project is [Icinga/icingadb](https://github.com/Icinga/icingadb), licensed under GPL-2.0-only.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Icinga is a trademark of Icinga GmbH. All rights in the mark are reserved to Icinga GmbH. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation with Icinga GmbH.

Redis® is a registered trademark of Redis Ltd. Any rights therein are reserved to Redis Ltd. Any use by Docker is for
referential purposes only and does not indicate any sponsorship, endorsement, or affiliation between Redis Ltd. and
Docker. For the upstream project's trademark acknowledgements, see
[Third-party Trademarks](https://github.com/Icinga/icingadb/blob/v1.6.0/doc/TRADEMARKS.md).

This listing is prepared by Docker. All other third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
