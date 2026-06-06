## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Getting Started with DuckDuckGo MCP Server

The DuckDuckGo MCP Server runs as a Model Context Protocol server. By default it communicates over stdio and is launched
as a child process by an MCP client (such as Claude Desktop). It can also be run as a long-lived service using the SSE
or streamable-http transports.

### Running the Server

To run the server directly with the default stdio transport:

```bash
docker run --rm -i dhi.io/duckduckgo-mcp-server:<tag>
```

The `-i` flag is required so the container's stdin remains attached for MCP message exchange.

To run the server with an HTTP transport (binds `0.0.0.0:8000` inside the container):

```bash
docker run --rm -p 8000:8000 dhi.io/duckduckgo-mcp-server:<tag> \
  --transport streamable-http --host 0.0.0.0 --port 8000
```

### Configuration

The server reads two optional environment variables at startup:

| Variable          | Description                                           | Values                                |
| ----------------- | ----------------------------------------------------- | ------------------------------------- |
| `DDG_SAFE_SEARCH` | SafeSearch filtering level applied to every search    | `STRICT`, `MODERATE` (default), `OFF` |
| `DDG_REGION`      | Default region/language code used when none specified | e.g. `us-en`, `jp-ja`, `wt-wt`        |

The DHI image does not include the optional `[browser]` extra (`curl_cffi`), so the `--fetch-backend curl` and
`--fetch-backend auto` modes are not available. The default `httpx` backend is used for all content fetches.

#### Claude Desktop Configuration

Add the following to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "ddg-search": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "dhi.io/duckduckgo-mcp-server:<tag>"
      ]
    }
  }
}
```

To configure SafeSearch or a default region, pass environment variables through Docker:

```json
{
  "mcpServers": {
    "ddg-search": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "DDG_SAFE_SEARCH=STRICT",
        "-e", "DDG_REGION=us-en",
        "dhi.io/duckduckgo-mcp-server:<tag>"
      ]
    }
  }
}
```

Restart Claude Desktop after editing the configuration file.

### Available Tools

Once configured, the server exposes two tools to the MCP client:

#### `search`

Performs a DuckDuckGo web search and returns formatted results.

**Parameters:**

- `query` (string, required): the search query
- `max_results` (integer, optional): maximum number of results to return (default: 10)
- `region` (string, optional): region/language code to override `DDG_REGION` for this call

#### `fetch_content`

Fetches a URL and returns cleaned, paginatable text.

**Parameters:**

- `url` (string, required): the URL to fetch
- `start_index` (integer, optional): character offset to start reading from (default: 0)
- `max_length` (integer, optional): maximum number of characters to return (default: 8000)
- `backend` (string, optional): per-call backend override. In this DHI image only `"httpx"` is available; `"curl"` and
  `"auto"` require the upstream `[browser]` extra, which this image does not ship.

### Rate Limiting

The server enforces built-in rate limits on each tool to avoid overwhelming DuckDuckGo:

- `search`: 30 requests per minute
- `fetch_content`: 20 requests per minute

When a limit is reached the server queues requests and waits transparently.

### Integration Examples

#### With Docker Compose

```yaml
services:
  duckduckgo-mcp-server:
    image: dhi.io/duckduckgo-mcp-server:<tag>
    stdin_open: true
    tty: true
```

## Additional Resources

- [Model Context Protocol Documentation](https://modelcontextprotocol.io/)
- [DuckDuckGo MCP Server source code](https://github.com/nickclyde/duckduckgo-mcp-server)
- [DuckDuckGo MCP Server on PyPI](https://pypi.org/project/duckduckgo-mcp-server/)

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened DuckDuckGo MCP Server  | Docker Hardened DuckDuckGo MCP Server               |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-duckduckgo-mcp-server \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/duckduckgo-mcp-server:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                  |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                 |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                         |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The DuckDuckGo MCP Server's default port (8000) is unprivileged. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
   runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use apk to install packages. For Debian-based images, you can use apt-get to install
   packages.

## Troubleshoot migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The default
DuckDuckGo MCP Server transport port (8000) is unprivileged, so this typically does not affect normal usage.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
