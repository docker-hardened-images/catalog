## About Couchbase MCP Server

The Couchbase MCP Server is the official [Model Context Protocol](https://spec.modelcontextprotocol.io/) implementation
for [Couchbase](https://www.couchbase.com/), maintained by Couchbase's Developer Experience & Ecosystem team. It
connects AI tools and assistants to Couchbase clusters, letting agents run SQL++ queries, browse buckets, scopes, and
collections, perform key-value operations, inspect schema, and check cluster health through natural language
interactions.

The server communicates over stdio transport (the default mode used by desktop MCP clients) and is launched as a
one-shot container; it can also run in HTTP or SSE mode for remote clients. It is **read-only by default** — all write
operations are disabled unless explicitly enabled — and supports both username/password and mutual-TLS authentication.
Connection details are supplied through the `CB_CONNECTION_STRING`, `CB_USERNAME`, and `CB_PASSWORD` environment
variables. The RBAC permissions granted to the Couchbase user remain the primary security control; the server's
read-only mode and tool-disabling options provide additional layers.

For more details, visit https://mcp-server.couchbase.com/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Couchbase® is a registered trademark of Couchbase, Inc. All rights in the mark are reserved to Couchbase, Inc. Any use
by Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
