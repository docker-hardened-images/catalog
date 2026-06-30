## About Patroni

Patroni is a template for PostgreSQL high availability. It runs alongside a PostgreSQL instance and uses a distributed
configuration store (Etcd, Consul, ZooKeeper, or Kubernetes) to elect a primary, promote replicas on failure, and keep
cluster topology consistent. The `patronictl` command-line tool lets operators inspect cluster state, trigger manual
failover or switchover, and reload or restart members.

This image bundles Patroni with a Docker Hardened PostgreSQL base, giving each cluster member a single self-contained
runtime: the Postgres binaries, the Patroni daemon, and the most common DCS client libraries (etcd3, Kubernetes) plus
the psycopg3 PostgreSQL driver. Configure Patroni via `PATRONI_*` environment variables or a YAML config file mounted
into the container; the image does not include a configuration of its own.

For more information, visit https://github.com/patroni/patroni and https://patroni.readthedocs.io.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

PostgreSQL® is a trademark of PostgreSQL Community Association of Canada. All rights in the mark are reserved to
PostgreSQL Community Association of Canada. Any use by Docker is for referential purposes only and does not indicate
sponsorship, endorsement, or affiliation.

Patroni is open-source software distributed under the MIT License. Use by Docker is for referential purposes only and
does not indicate sponsorship, endorsement, or affiliation.
