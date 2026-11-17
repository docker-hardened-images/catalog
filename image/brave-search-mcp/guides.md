## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this brave-search-mcp image

The Brave Search MCP Server is the official [Model Context Protocol](https://spec.modelcontextprotocol.io/)
implementation for the [Brave Search API](https://brave.com/search/api/), maintained by Brave Software, Inc. It exposes
the Brave Search API to MCP clients, enabling AI agents to run web, image, video, news, and local searches and to
retrieve AI-generated summaries directly.

The server is built on Node.js and communicates over stdio transport by default, which is the standard MCP transport
used by desktop clients such as Claude Desktop, Cursor, and VS Code. An optional HTTP transport is also supported for
web-based or remote deployments. Authentication uses a Brave Search API key (`BRAVE_API_KEY`), which can be created at
[https://api-dashboard.search.brave.com/app/keys](https://api-dashboard.search.brave.com/app/keys).

### Run the brave-search-mcp container

The server communicates over stdio, so the container must be launched with `-i` (interactive) to keep stdin open. The
`--rm` flag removes the container when the MCP client disconnects.

To verify the image works and print help information:

```bash
docker run --rm dhi.io/brave-search-mcp:2 --help
```

To run the server for use by an MCP client:

```bash
docker run --rm -i \
  -e BRAVE_API_KEY=**** \
  dhi.io/brave-search-mcp:2
```

Replace `****` with your Brave Search API key.

### Authenticate with a Brave Search API key

The server requires a Brave Search API key to access the Brave Search API. Create one at
[https://api-dashboard.search.brave.com/app/keys](https://api-dashboard.search.brave.com/app/keys).

Pass the key via the `BRAVE_API_KEY` environment variable:

```bash
docker run --rm -i \
  -e BRAVE_API_KEY=**** \
  dhi.io/brave-search-mcp:2
```

The key can also be supplied as a command-line argument with `--brave-api-key`, which takes precedence over the
environment variable:

```bash
docker run --rm -i \
  dhi.io/brave-search-mcp:2 \
  --brave-api-key ****
```

### Configure an MCP client

#### Claude Desktop

Add the following entry to your `claude_desktop_config.json` (macOS:
`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "braveSearch": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "BRAVE_API_KEY",
        "dhi.io/brave-search-mcp:2"
      ],
      "env": {
        "BRAVE_API_KEY": "****"
      }
    }
  }
}
```

Passing the key via the `env` block (rather than inline in `args`) avoids shell-escaping issues with the value.

#### Cursor

Add the following to `.cursor/mcp.json` at the root of your project or to your global Cursor settings:

```json
{
  "mcpServers": {
    "braveSearch": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "BRAVE_API_KEY",
        "dhi.io/brave-search-mcp:2"
      ],
      "env": {
        "BRAVE_API_KEY": "****"
      }
    }
  }
}
```

#### VS Code

Add the following to `.vscode/mcp.json` at the root of your project:

```json
{
  "servers": {
    "braveSearch": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "BRAVE_API_KEY",
        "dhi.io/brave-search-mcp:2"
      ],
      "env": {
        "BRAVE_API_KEY": "****"
      }
    }
  }
}
```

### Run with HTTP transport

The server also supports an optional HTTP transport for web-based clients or remote deployments. Pass `--transport http`
and `--port <port>` as container arguments after the image name (the default port is `8080`):

```bash
docker run --rm \
  -p 8080:8080 \
  -e BRAVE_API_KEY=**** \
  dhi.io/brave-search-mcp:2 \
  --transport http --port 8080
```

The transport, port, and host can also be configured through the `BRAVE_MCP_TRANSPORT`, `BRAVE_MCP_PORT`, and `--host`
options respectively. The server binds to `0.0.0.0` by default when using HTTP transport.

> **Note:** The DHI image does not expose a port by default because stdio is the primary transport mode. Publish the
> port explicitly with `-p` when using HTTP transport.

### Control which tools are exposed

The server exposes web, image, video, news, local, and summarizer search tools. You can restrict the set of enabled
tools with `--enabled-tools` (an allowlist) or `--disabled-tools` (a denylist), which is useful for limiting an agent's
capabilities:

```bash
docker run --rm -i \
  -e BRAVE_API_KEY=**** \
  dhi.io/brave-search-mcp:2 \
  --enabled-tools brave_web_search brave_summarizer
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate from the upstream image

The DHI image is a drop-in replacement for the upstream `brave-search-mcp-server` image. The entrypoint
(`node /app/dist/index.js`), default stdio transport, and `BRAVE_API_KEY` authentication are unchanged, so existing MCP
client configurations work by swapping the image reference.

Key differences from the upstream image:

- The image is built on the Docker Hardened Images Node.js base, runs as a non-root user, and contains no shell or
  package manager.

Update the image reference in your MCP client configuration:

```diff
-        "ghcr.io/brave/brave-search-mcp-server:latest"
+        "dhi.io/brave-search-mcp:2"
```
