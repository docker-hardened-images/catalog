## About Fetch MCP Server

The Fetch MCP Server is a Model Context Protocol server that provides web content fetching capabilities. This server
enables Large Language Models (LLMs) to retrieve and process content from web pages, converting HTML to markdown for
easier consumption and analysis.

The server provides a `fetch` tool that can:

- Fetch content from any URL
- Convert HTML to clean, readable markdown
- Handle content truncation with pagination support
- Respect robots.txt and provide safe web scraping
- Return raw HTML when markdown conversion is not desired

### Key Features

- **HTML to Markdown Conversion**: Automatically converts web content to markdown format, making it easier for LLMs to
  process
- **Pagination Support**: Large pages can be fetched in chunks using the `start_index` parameter
- **Flexible Output**: Choose between markdown conversion or raw HTML content
- **Safe Fetching**: Respects robots.txt and follows web scraping best practices
- **Configurable Length**: Control the maximum amount of content returned per request

### Use Cases

- Research and information gathering for AI assistants
- Web content analysis and summarization
- Automated documentation extraction
- Content aggregation and monitoring
- Knowledge base construction

For more details, see the [official documentation](https://github.com/modelcontextprotocol/servers/tree/main/src/fetch).

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
