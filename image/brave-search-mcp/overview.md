## About Brave Search MCP Server

The Brave Search MCP Server is the official [Model Context Protocol](https://spec.modelcontextprotocol.io/)
implementation for the [Brave Search API](https://brave.com/search/api/), maintained by Brave Software, Inc. It exposes
the Brave Search API to MCP clients — covering web, image, video, news, and local search, as well as AI-generated
summaries — so that AI agents such as Claude Desktop, Cursor, VS Code, and other MCP clients can run searches and
retrieve results directly.

The server supports both stdio transport (default, used by most desktop MCP clients) and an optional HTTP transport for
web-based or remote deployments. Authentication is handled through a Brave Search API key (`BRAVE_API_KEY`), which can
be created at [https://api-dashboard.search.brave.com/app/keys](https://api-dashboard.search.brave.com/app/keys).

For more details, visit https://github.com/brave/brave-search-mcp-server.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Brave® is a trademark of Brave Software, Inc. All rights in the mark are reserved to Brave Software, Inc. Any use by
Docker is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
