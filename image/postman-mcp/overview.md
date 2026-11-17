## About Postman MCP Server

The Postman MCP Server is the official [Model Context Protocol](https://spec.modelcontextprotocol.io/) implementation
for the [Postman API](https://www.postman.com/postman-api/), maintained by Postman Labs. It connects AI tools and
assistants to Postman's platform, giving agents the ability to access workspaces, manage collections and environments,
evaluate API specifications, and automate workflows through natural language interactions.

The server communicates over stdio transport (the default mode used by desktop MCP clients) and is launched as a
one-shot container. It supports three tool configurations: **Minimal** (default, essential tools for basic Postman
operations), **Code** (adds API code-generation tools), and **Full** (100+ tools covering the full Postman API).
Authentication requires a Postman API key passed via the `POSTMAN_API_KEY` environment variable.

For more details, visit https://www.postman.com/product/mcp-server/.

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

Postman® is a trademark of Postman, Inc. All rights in the mark are reserved to Postman, Inc. Any use by Docker is for
referential purposes only and does not indicate sponsorship, endorsement, or affiliation.
