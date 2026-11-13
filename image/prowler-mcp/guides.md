## How to use this image

Authenticate with `docker login dhi.io` before pulling the image.

### Stdio mode (default)

Run with an interactive stdin so an MCP client can exchange protocol messages:

```bash
docker run --rm -i \
  -e PROWLER_API_KEY \
  -e API_BASE_URL=https://api.prowler.com/api/v1 \
  dhi.io/prowler-mcp:<tag>
```

Set `PROWLER_API_KEY` in the parent environment from a secrets manager; do not put its value in the command or configuration file. The key is optional when only Prowler Hub and documentation tools are used.

Example MCP client configuration:

```json
{
  "mcpServers": {
    "prowler": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "-e", "PROWLER_API_KEY", "dhi.io/prowler-mcp:<tag>"]
    }
  }
}
```

### Streamable HTTP mode

Override the CLI arguments and bind to all container interfaces:

```bash
docker run --rm -p 8000:8000 \
  dhi.io/prowler-mcp:<tag> \
  --transport http --host 0.0.0.0 --port 8000
```

The MCP endpoint is available at `http://localhost:8000/mcp` and health status at `http://localhost:8000/health`. HTTP clients authenticate Prowler application tools with `Authorization: Bearer <API-key-or-JWT>`. Terminate TLS at a trusted reverse proxy, restrict network access, and never log authorization headers.

### Environment variables

| Variable | Purpose | Required |
| --- | --- | --- |
| `PROWLER_API_KEY` | API key used by Prowler application tools in stdio mode. Treat as secret. | For authenticated stdio tools |
| `PROWLER_APP_API_KEY` | Deprecated compatibility alias for `PROWLER_API_KEY`. | No |
| `API_BASE_URL` | Prowler API v1 base URL; defaults to `https://api.prowler.com/api/v1`. | No |
| `PROWLER_MCP_TRANSPORT_MODE` | Alternative to `--transport`; accepts `stdio` or `http`. | No |

CLI flags take precedence when supplied. The image exposes port 8000 as documentation; stdio mode does not open a network listener.

## Migration notes

| Item | Upstream image | Docker Hardened Image |
| --- | --- | --- |
| Image | `prowlercloud/prowler-mcp:5.36.0` | `dhi.io/prowler-mcp:<tag>` |
| User | Upstream `prowler` uid 1001 | `nonroot` uid/gid 65532 |
| Default | Entrypoint wrapper, `main` command | Direct `prowler-mcp`, native stdio default |
| HTTP | `--transport http --host 0.0.0.0 --port 8000` | Same CLI arguments |
| Runtime | Alpine Python | Minimal Debian 13 Python |

The runtime has no shell or package manager. Use Docker Debug for troubleshooting rather than modifying the running image.

## Security best practices

- Scope API keys to only the tenants and operations the MCP client needs.
- Prefer read-only access where possible and rotate keys regularly.
- Keep stdio containers ephemeral with `--rm` and do not persist their environment.
- Put HTTP mode behind TLS, authentication-aware ingress, and network policy.
- Treat MCP tool output as potentially sensitive security data.

## Additional resources

- [Prowler MCP overview](https://docs.prowler.com/getting-started/products/prowler-mcp)
- [Prowler MCP installation](https://docs.prowler.com/getting-started/installation/prowler-mcp)
- [Prowler MCP tools](https://docs.prowler.com/getting-started/basic-usage/prowler-mcp-tools)
- [Model Context Protocol](https://modelcontextprotocol.io/)
