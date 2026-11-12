## About StackHawk MCP Server

The StackHawk MCP Server is a Model Context Protocol (MCP) server that connects AI coding assistants and LLM-powered
IDEs to the [StackHawk](https://www.stackhawk.com/) application security testing platform. It exposes StackHawk's
dynamic application security testing (DAST) capabilities as MCP tools so that AI assistants can help set up scanning,
run security scans, and triage findings directly from a developer's workflow.

The server provides tools to:

- Set up StackHawk scanning for a project
- Run dynamic application security scans
- Triage and review vulnerability findings
- Validate StackHawk YAML configuration files against the official schema

### Configuration

The server authenticates to StackHawk using an API key supplied through the `STACKHAWK_API_KEY` environment variable.
This value is a secret and must be provided at runtime; it is never baked into the image. The optional
`STACKHAWK_BASE_URL` environment variable can be used to point at a different StackHawk endpoint.

The server communicates over the MCP standard input/output (stdio) transport, which is the deployment model used by MCP
clients such as Claude Desktop, Cursor, and GitHub Copilot.

For more details, see the [upstream project](https://github.com/stackhawk/stackhawk-mcp).

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
