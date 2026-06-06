## About DuckDuckGo MCP Server

The DuckDuckGo MCP Server is a Model Context Protocol server that provides web search capabilities through DuckDuckGo,
with additional features for content fetching and parsing. It enables MCP-compatible clients such as Claude Desktop and
Claude Code to perform web searches and retrieve cleaned, LLM-friendly text from arbitrary URLs.

The server exposes two tools to MCP clients:

- A `search` tool that queries DuckDuckGo and returns formatted results
- A `fetch_content` tool that retrieves a URL and returns cleaned, paginatable text content

### Key Features

- **Web Search**: Query DuckDuckGo with configurable region, SafeSearch level, and result limit
- **Content Fetching**: Retrieve and parse webpage content with intelligent text extraction and pagination
- **Rate Limiting**: Built-in protection (30 search requests/min, 20 fetch requests/min) to stay within reasonable usage
- **LLM-Friendly Output**: Results formatted for direct consumption by large language models
- **Multiple Transports**: Supports `stdio` (default), `sse`, and `streamable-http` for different client integrations

### Use Cases

- Web search and research workflows for AI assistants
- Content summarization and analysis from URLs
- Knowledge base construction from public web sources
- Automated documentation retrieval and extraction

For more details, see the [upstream project](https://github.com/nickclyde/duckduckgo-mcp-server).

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
