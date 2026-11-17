## About Apollo MCP Server

Apollo MCP Server exposes a GraphQL API to AI agents through the Model Context Protocol, turning GraphQL operations into
MCP tools that any MCP client can call. It reads its schema and operations from local files, from a persisted-query
manifest, or directly from an Apollo GraphOS graph, and can additionally offer schema introspection and search so agents
can compose their own operations at runtime.

The server is written in Rust and speaks both the stdio and streamable HTTP MCP transports, which makes it equally
suitable for a desktop MCP client launched per session and for a long-running deployment fronting a production graph.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Apollo®, Apollo GraphQL®, and GraphOS® are registered trademarks of Apollo Graph, Inc. This listing is not endorsed by,
affiliated with, or associated with Apollo Graph, Inc. Any use by Docker is for referential purposes only. See the
[Apollo Trademark Guidelines](https://www.apollographql.com/trademarks).
