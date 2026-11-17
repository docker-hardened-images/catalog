## About PostgreSQL

PostgreSQL, often simply "Postgres", is an object-relational database management system (ORDBMS) with an emphasis on
extensibility and standards-compliance. As a database server, its primary function is to store data, securely and
supporting best practices, and retrieve it later, as requested by other software applications, be it those on the same
computer or those running on another computer across a network (including the Internet). It can handle workloads ranging
from small single-machine applications to large Internet-facing applications with many concurrent users. Recent versions
also provide replication of the database itself for security and scalability.

PostgreSQL implements the majority of the SQL:2011 standard, is ACID-compliant and transactional (including most DDL
statements) avoiding locking issues using multiversion concurrency control (MVCC), provides immunity to dirty reads and
full serializability; handles complex SQL queries using many indexing methods that are not available in other databases;
has updateable views and materialized views, triggers, foreign keys; supports functions and stored procedures, and other
expandability, and has a large number of extensions written by third parties. In addition to the possibility of working
with the major proprietary and open source databases, PostgreSQL supports migration from them, by its extensive standard
SQL support and available migration tools. And if proprietary extensions had been used, by its extensibility that can
emulate many through some built-in and third-party open source compatibility extensions, such as for Oracle.

For more information, visit https://www.postgresql.org/.

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
