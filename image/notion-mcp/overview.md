## About Notion MCP Server

The Notion MCP Server is the official [Model Context Protocol](https://spec.modelcontextprotocol.io/) implementation for
the [Notion API](https://developers.notion.com/reference/intro), maintained by Notion Labs. It exposes 22 Notion API
tools to MCP clients — covering pages, databases (data sources), comments, blocks, users, and search — so that AI agents
such as Claude Desktop, Cursor, Zed, and GitHub Copilot CLI can read and write content in Notion workspaces directly.

The server supports both stdio transport (default, used by most desktop MCP clients) and streamable HTTP transport for
web-based or remote deployments. Authentication is handled through a Notion internal integration token
(`NOTION_TOKEN=ntn_****`), which can be created at
[https://www.notion.so/profile/integrations](https://www.notion.so/profile/integrations).

> **Note:** Notion Labs is prioritizing their remote Notion MCP server (available at
> [developers.notion.com/docs/mcp](https://developers.notion.com/docs/mcp)), which offers OAuth-based setup and enhanced
> AI-agent tooling. The upstream project has stated that they may sunset this local MCP server in the future and are not
> actively monitoring issues and pull requests for it.

For more details, visit https://github.com/makenotion/notion-mcp-server.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with zero-known CVEs, include signed provenance, and come with a complete Software Bill of
Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly into
existing Docker workflows.

## Trademarks

Notion® is a trademark of Notion Labs, Inc. All rights in the mark are reserved to Notion Labs, Inc. Any use by Docker
is for referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
