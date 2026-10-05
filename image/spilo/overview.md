## About Spilo

Spilo is Zalando's high-availability PostgreSQL appliance: one image that combines
[Patroni](https://github.com/patroni/patroni) for cluster management and automatic failover, a bundle of PostgreSQL
major versions for in-place `pg_upgrade` migrations, [WAL-G](https://github.com/wal-g/wal-g) for continuous archiving
and base backups, and the PostgreSQL extension set the Zalando fleet runs in production (PostGIS, TimescaleDB, pgvector,
pg_partman, pglogical, pgaudit, and many more). It is the image the
[Zalando postgres-operator](https://github.com/zalando/postgres-operator) deploys, and it also runs standalone against
an etcd, Consul, or ZooKeeper DCS.

This image builds Spilo from the maintained 4.1 source line with PostgreSQL 17 as the primary version and PostgreSQL 14,
15, and 16 bundled for in-place major upgrades. The PostgreSQL servers, pgbouncer, and WAL-G install from Docker
Hardened packages, and every extension is compiled from pinned upstream sources against those servers. The older majors
exist as `pg_upgrade` sources and follow upstream's five-year support policy (PostgreSQL 14 ends in November 2026).

Deviations from the upstream `ghcr.io/zalando/spilo-*` images:

- PostgreSQL 17 is the primary on the Spilo 4.1 line (upstream publishes the 4.1 line only as a PostgreSQL 18-primary
  image; the frozen upstream `spilo-17` repository ends at Spilo 4.0-p3).
- The embedded etcd server and etcdctl (end-of-life v3.3) are not shipped; point the image at a real DCS.
- The Ubuntu 18.04 compatibility locale archive is not shipped; `USE_OLD_LOCALES` is unsupported (see the migration
  notes in the guides).
- pg_view is not shipped.
- `chrt`/`renice` carry no file capabilities; grant `CAP_SYS_NICE` at runtime if you want Patroni real-time scheduling.
- The container runs as the `postgres` user (uid 70) by default instead of root.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

PostgreSQL® is a trademark of PostgreSQL Community Association of Canada. TimescaleDB® is a trademark of Timescale, Inc.
All rights in those marks are reserved to their respective owners. Any use by Docker is for referential purposes only
and does not indicate sponsorship, endorsement, or affiliation.

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
