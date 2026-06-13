## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this notion-mcp-server image

The Notion MCP Server is the official [Model Context Protocol](https://spec.modelcontextprotocol.io/) implementation for
the [Notion API](https://developers.notion.com/reference/intro), maintained by Notion Labs. It exposes 22 Notion API
tools to MCP clients, enabling AI agents to read and write pages, databases (data sources), comments, blocks, users, and
search results directly in Notion workspaces.

The server is built on Node.js and communicates over stdio transport by default, which is the standard MCP transport
used by desktop clients such as Claude Desktop, Cursor, Zed, and GitHub Copilot CLI. An optional streamable HTTP
transport is also supported for web-based or remote deployments. Authentication uses a Notion internal integration token
(`NOTION_TOKEN`), which can be created at
[https://www.notion.so/profile/integrations](https://www.notion.so/profile/integrations).

### Run the notion-mcp-server container

The server communicates over stdio, so the container must be launched with `-i` (interactive) to keep stdin open. The
`--rm` flag removes the container when the MCP client disconnects.

To verify the image works and print help information:

```bash
docker run --rm dhi.io/notion-mcp-server:2 --help
```

To run the server for use by an MCP client:

```bash
docker run --rm -i \
  -e NOTION_TOKEN=ntn_**** \
  dhi.io/notion-mcp-server:2
```

Replace `ntn_****` with your Notion integration token.

### Authenticate with a Notion integration token

The server requires a Notion internal integration token to access your workspace. Create one at
[https://www.notion.so/profile/integrations](https://www.notion.so/profile/integrations) and connect it to the pages or
databases you want the AI agent to access.

Pass the token via the `NOTION_TOKEN` environment variable:

```bash
docker run --rm -i \
  -e NOTION_TOKEN=ntn_**** \
  dhi.io/notion-mcp-server:2
```

For advanced use cases — such as specifying a custom `Notion-Version` header or using a different authorization scheme —
you can use the `OPENAPI_MCP_HEADERS` environment variable instead. This accepts a JSON-encoded object of HTTP headers:

```bash
docker run --rm -i \
  -e 'OPENAPI_MCP_HEADERS={"Authorization":"Bearer ntn_****","Notion-Version":"2025-09-03"}' \
  dhi.io/notion-mcp-server:2
```

When `OPENAPI_MCP_HEADERS` is set, its `Authorization` header takes precedence over `NOTION_TOKEN`.

### Configure an MCP client

#### Claude Desktop

Add the following entry to your `claude_desktop_config.json` (macOS:
`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "notionApi": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "NOTION_TOKEN",
        "dhi.io/notion-mcp-server:2"
      ],
      "env": {
        "NOTION_TOKEN": "ntn_****"
      }
    }
  }
}
```

Passing the token via the `env` block (rather than inline in `args`) avoids shell-escaping issues with the JSON value.

#### Cursor

Add the following to `.cursor/mcp.json` at the root of your project or to your global Cursor settings:

```json
{
  "mcpServers": {
    "notionApi": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "NOTION_TOKEN",
        "dhi.io/notion-mcp-server:2"
      ],
      "env": {
        "NOTION_TOKEN": "ntn_****"
      }
    }
  }
}
```

#### Zed

Add to your `settings.json`:

```json
{
  "context_servers": {
    "notionApi": {
      "command": {
        "path": "docker",
        "args": [
          "run",
          "--rm",
          "-i",
          "-e", "NOTION_TOKEN",
          "dhi.io/notion-mcp-server:2"
        ],
        "env": {
          "NOTION_TOKEN": "ntn_****"
        }
      },
      "settings": {}
    }
  }
}
```

### Run with streamable HTTP transport

The server also supports an optional streamable HTTP transport for web-based clients or remote deployments. Pass
`--transport http` and `--port <port>` as container arguments after the image name:

```bash
docker run --rm \
  -p 3000:3000 \
  -e NOTION_TOKEN=ntn_**** \
  dhi.io/notion-mcp-server:2 \
  --transport http --port 3000
```

The server listens on `0.0.0.0:<port>/mcp`. A health check endpoint is available at `/health`.

> **Note:** The DHI image does not expose a port by default because stdio is the primary transport mode. Publish the
> port explicitly with `-p` when using HTTP transport.

#### HTTP transport authentication

Bearer token authentication is enabled by default when using HTTP transport. You can configure the token in three ways:

Auto-generated token (the server prints it to the console on startup, suitable for development):

```bash
docker run --rm -p 3000:3000 -e NOTION_TOKEN=ntn_**** \
  dhi.io/notion-mcp-server:2 --transport http --port 3000
```

Custom token via command-line argument (recommended for production):

```bash
docker run --rm -p 3000:3000 -e NOTION_TOKEN=ntn_**** \
  dhi.io/notion-mcp-server:2 \
  --transport http --port 3000 --auth-token "your-secret-token"
```

Custom token via environment variable:

```bash
docker run --rm -p 3000:3000 \
  -e NOTION_TOKEN=ntn_**** \
  -e AUTH_TOKEN=your-secret-token \
  dhi.io/notion-mcp-server:2 --transport http --port 3000
```

The `--auth-token` argument takes precedence over the `AUTH_TOKEN` environment variable when both are set. To disable
authentication entirely (not recommended for production), add `--disable-auth`:

```bash
docker run --rm -p 3000:3000 -e NOTION_TOKEN=ntn_**** \
  dhi.io/notion-mcp-server:2 \
  --transport http --port 3000 --disable-auth
```

All HTTP requests must include the bearer token in the `Authorization` header. The MCP Streamable HTTP transport also
requires an `Accept: application/json, text/event-stream` header. The session id is assigned by the server — do not
supply `mcp-session-id` on the `initialize` call; the server returns it in the `Mcp-Session-Id` response header for use
on subsequent requests:

```bash
curl -i -H "Authorization: Bearer your-secret-token" \
     -H "Content-Type: application/json" \
     -H "Accept: application/json, text/event-stream" \
     -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"curl","version":"1.0"}},"id":1}' \
     http://localhost:3000/mcp
```

### Available tools

The server exposes 22 Notion API tools to connected MCP clients. Tool discovery is automatic — clients see the full list
when the server starts.

> **Note:** Tool names exposed to MCP clients are prefixed with `API-` (for example, `API-retrieve-a-page`,
> `API-query-data-source`). The server adds this prefix from the bundled OpenAPI specification.

Key tool categories include:

- **Pages**: retrieve, create, update, move, and archive pages
- **Data sources (databases)**: query, retrieve, create, and update data sources; list data source templates
- **Databases**: retrieve database metadata and data source IDs (`API-retrieve-a-database`)
- **Blocks**: retrieve and append block children
- **Comments**: create and retrieve comments
- **Users**: retrieve users and list workspace members
- **Search**: search across pages and data sources

> **Note:** Version 2.0.0 migrated to the Notion API 2025-09-03, which replaces database tools with data source tools.
> If you are upgrading from v1.x, the old `API-post-database-query`, `API-update-a-database`, and
> `API-create-a-database` tools are no longer available. Use `API-query-data-source`, `API-update-a-data-source`, and
> `API-create-a-data-source` instead.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
