## About Directus

[Directus](https://directus.com) wraps any SQL database with a REST and GraphQL API layer and a visual admin app, the
Studio. Engineers control the schema and the access policies, and other teammates and AI agents work with live data
through the API, the Studio or the built-in MCP server. It connects to PostgreSQL, MySQL, MariaDB, SQLite, Microsoft SQL
Server, OracleDB and CockroachDB and can be extended with custom endpoints, hooks, interfaces and modules.

This image runs the Directus API and Studio under Node.js with the pm2 process supervisor, the same way the upstream
`directus/directus` image does, and replaces it.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Directus is a trademark of Monospace Inc. Directus is distributed under the Monospace Sustainable Core License 1.0,
whose trademark clause allows the name to be used only to identify the origin of the software. All rights in the mark
are reserved to Monospace Inc. Any use by Docker is for referential purposes only and does not indicate sponsorship,
endorsement, or affiliation.
