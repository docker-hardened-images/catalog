## About Memcached

Memcached is a general-purpose distributed memory caching system. It is often used to speed up dynamic database-driven
websites by caching data and objects in RAM to reduce the number of times an external data source (such as a database or
API) must be read.

Memcached's APIs provide a very large hash table distributed across multiple machines. When the table is full,
subsequent inserts cause older data to be purged in least recently used order. Applications using Memcached typically
layer requests and additions into RAM before falling back on a slower backing store, such as a database.

For more details, visit https://docs.memcached.org/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
