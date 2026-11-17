## About Zscaler MCP Server

The Zscaler MCP Server is a Model Context Protocol (MCP) server that connects AI coding assistants and LLM-powered IDEs
to the [Zscaler](https://www.zscaler.com/) Zero Trust Exchange platform. It exposes Zscaler's services — including
Zscaler Internet Access (ZIA), Zscaler Private Access (ZPA), Zscaler Digital Experience (ZDX), Zscaler Client Connector
(ZCC), and more — as MCP tools so that AI assistants can query and manage your Zscaler configuration directly from a
developer's workflow.

The server organizes its tools into toolsets per service and provides discovery tools to browse them:

- Discover the available services and toolsets
- Query Zscaler configuration (policies, segments, applications, and related resources)
- Enable additional toolsets on demand for the products your credentials can access

By default the server operates in **read-only mode** — only `list_*` and `get_*` operations are registered. Write
operations (create, update, delete) must be explicitly opted into with the `--enable-write-tools` flag together with an
allowlist, or via the `ZSCALER_MCP_WRITE_ENABLED` environment variable.

### Configuration

The server authenticates to Zscaler using OneAPI credentials supplied through environment variables:
`ZSCALER_CLIENT_ID`, `ZSCALER_CLIENT_SECRET`, `ZSCALER_CUSTOMER_ID`, and `ZSCALER_VANITY_DOMAIN`. The client ID and
secret are secrets and must be provided at runtime; they are never baked into the image.

The server communicates over the MCP standard input/output (stdio) transport by default, which is the deployment model
used by MCP clients such as Claude Desktop, Cursor, and GitHub Copilot. The `sse` and `streamable-http` transports are
also supported via the `--transport` flag.

For more details, see the [upstream project](https://github.com/zscaler/zscaler-mcp-server).

## About Docker Hardened Images

Docker Hardened Images are built to meet the highest security and compliance standards. They provide a trusted
foundation for containerized workloads by incorporating security best practices from the start.

### Why use Docker Hardened Images?

These images are published with near-zero known CVEs, include signed provenance, and come with a complete Software Bill
of Materials (SBOM) and VEX metadata. They're designed to secure your software supply chain while fitting seamlessly
into existing Docker workflows.

## Trademarks

This listing is prepared by Docker. All third-party product names, logos, and trademarks are the property of their
respective owners and are used solely for identification. Docker claims no interest in those marks, and no affiliation,
sponsorship, or endorsement is implied.
