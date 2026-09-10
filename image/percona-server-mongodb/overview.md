## About Percona Server for MongoDB

Percona Server for MongoDB is an enhanced, fully compatible, source-available, drop-in replacement for MongoDB Community
Edition. It is based on the MongoDB Community Edition code base and extends it with functionality otherwise only
available in MongoDB Enterprise Edition: data-at-rest encryption with HashiCorp Vault, KMIP or OpenBao key management,
LDAP, Kerberos, AWS IAM and OIDC authentication, audit logging, log redaction, hot backup, the Percona Memory Engine and
a rate-limited database profiler.

This image ships `mongod`, `mongos`, `mongosh`, `perconadecrypt` and the MongoDB database tools (`mongodump`,
`mongorestore`, `mongoexport`, `mongoimport`, `mongostat`, `mongotop`, `mongofiles` and `bsondump`). Additional
information about Percona software packages and repositories is available at:
https://docs.percona.com/percona-software-repositories/

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Percona and the Percona logo are trademarks of Percona LLC. MongoDB®, Mongo®, and the leaf logo are registered
trademarks of MongoDB, Inc. All rights in the marks are reserved to their respective owners. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation. See
https://www.percona.com/trademark-policy/ for Percona's trademark policy.
