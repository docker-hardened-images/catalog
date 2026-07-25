## About Prowler MCP Server

The official Prowler MCP Server connects AI assistants and agents to the Prowler ecosystem through the Model Context Protocol. Its namespaced tools can query and manage Prowler findings, finding groups, providers, scans, resources, muting, compliance data, and attack paths. It also exposes unauthenticated search tools for Prowler Hub and the official Prowler documentation.

## About this image

This image packages the MCP server released with Prowler 5.36.0 (MCP package 0.8.0) from its locked uv environment. It runs stdio transport by default for desktop and editor MCP clients. The same executable supports streamable HTTP transport with `--transport http`; HTTP mode listens on port 8000 when configured with `--host 0.0.0.0 --port 8000`.

The runtime is a minimal Debian 13 Python image and runs as nonroot uid 65532. No credentials are embedded. Prowler Hub and documentation tools work without authentication; Prowler application tools require an API key in stdio mode or a bearer token supplied by each HTTP client.

## About Docker Hardened Images

Docker Hardened Images are built to meet high security and compliance standards. They provide a minimal, continuously maintained foundation, signed provenance, and a complete Software Bill of Materials (SBOM) and VEX metadata.

## Trademarks

Prowler is a trademark of Prowler, Inc. All third-party product names, logos, and trademarks are the property of their respective owners and are used solely for identification. Docker claims no affiliation, sponsorship, or endorsement.
