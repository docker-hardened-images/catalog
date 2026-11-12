## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Getting Started with Grafana MCP Server

The Grafana MCP Server can be configured to work with MCP clients to provide AI-powered access to your Grafana instance.

Before using the Grafana MCP Server, you'll need:

1. **Grafana Instance**: A running Grafana instance (version 9.0 or later)
1. **API Credentials**: Grafana API key or service account token
1. **Grafana URL**: The base URL of your Grafana instance

### Configuration

#### Claude Desktop Configuration

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "grafana": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "GRAFANA_URL=https://your-grafana-instance.com",
        "-e", "GRAFANA_TOKEN=your-api-token",
        "dhi.io/grafana-mcp"
      ]
    }
  }
}
```

#### Environment Variables

The server requires the following environment variables:

- `GRAFANA_URL` (required): The base URL of your Grafana instance
- `GRAFANA_TOKEN` (required): API key or service account token for authentication

### Transport Options

The server supports multiple transport modes:

**stdio (default)**: Standard input/output communication

```bash
docker run -i \
  -e GRAFANA_URL=https://your-grafana.com \
  -e GRAFANA_TOKEN=your-token \
  dhi.io/grafana-mcp \
  --transport stdio
```

**SSE**: Server-Sent Events for web-based clients

```bash
docker run -p 8000:8000 \
  -e GRAFANA_URL=https://your-grafana.com \
  -e GRAFANA_TOKEN=your-token \
  dhi.io/grafana-mcp \
  --transport sse \
  --address localhost:8000
```

**streamable-http**: HTTP streaming for compatibility

```bash
docker run -p 8000:8000 \
  -e GRAFANA_URL=https://your-grafana.com \
  -e GRAFANA_TOKEN=your-token \
  dhi.io/grafana-mcp \
  --transport streamable-http \
  --address localhost:8000
```

### Tool Configuration

Control which tool categories are enabled:

**Enable specific tools:**

```bash
docker run -i \
  -e GRAFANA_URL=https://your-grafana.com \
  -e GRAFANA_TOKEN=your-token \
  dhi.io/grafana-mcp \
  --enabled-tools search,datasource,prometheus
```

**Disable specific tools:**

```bash
docker run -i \
  -e GRAFANA_URL=https://your-grafana.com \
  -e GRAFANA_TOKEN=your-token \
  dhi.io/grafana-mcp \
  --disable-write \
  --disable-admin
```

### Read-Only Mode

For safe, read-only access to your Grafana instance:

```bash
docker run -i \
  -e GRAFANA_URL=https://your-grafana.com \
  -e GRAFANA_TOKEN=your-token \
  dhi.io/grafana-mcp \
  --disable-write
```

This prevents any create, update, or delete operations.

### Debug Mode

Enable detailed HTTP request/response logging:

```bash
docker run -i \
  -e GRAFANA_URL=https://your-grafana.com \
  -e GRAFANA_TOKEN=your-token \
  dhi.io/grafana-mcp \
  --debug
```

### Available Tool Categories

- **search**: Dashboard and resource search
- **datasource**: Datasource management and queries
- **prometheus**: Prometheus metric queries and metadata
- **loki**: Loki log queries and metadata
- **alerting**: Alert rules and contact points
- **dashboard**: Dashboard operations
- **incident**: Incident management
- **oncall**: OnCall schedule and user management
- **sift**: Sift investigation and analysis
- **asserts**: Asserts integration
- **pyroscope**: Pyroscope profiling
- **navigation**: Navigation tools
- **admin**: Administrative operations (disabled by default)

### Security Best Practices

1. **Use Service Accounts**: Create dedicated service accounts with minimal required permissions
1. **Read-Only When Possible**: Use `--disable-write` for queries and monitoring
1. **Network Isolation**: Run in isolated networks when accessing internal Grafana instances
1. **Token Management**: Store tokens securely using secrets management
1. **Audit Logging**: Enable debug mode in development, monitor in production

### Example Use Cases

**Dashboard Analysis**

```
Query: "What panels are in the 'System Overview' dashboard?"
Server retrieves dashboard by name and extracts panel information
```

**Metric Queries**

```
Query: "Show me CPU usage for the last hour"
Server executes Prometheus queries and returns metrics
```

**Alert Investigation**

```
Query: "Are there any firing alerts?"
Server checks alert rules and returns active alerts
```

**Incident Management**

```
Query: "Create a new incident for the database outage"
Server creates incident with appropriate severity and details
```

## Additional Resources

- [Grafana MCP Server GitHub](https://github.com/grafana/mcp-grafana)
- [Grafana API Documentation](https://grafana.com/docs/grafana/latest/developers/http_api/)
- [Model Context Protocol](https://modelcontextprotocol.io/)

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Argo CD                | Docker Hardened Argo CD                             |
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
docker run --rm -it --pid container:my-grafana-mcp \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/grafana-mcp:<tag> /dbg/bin/sh
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

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations.

For example, usage of MD5 fails in FIPS variants. To verify FIPS compliance, check the cryptographic module version in
use by your Argo CD instance.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                       |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                            |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                            |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                           |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                               |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                   |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Argo CD default ports work without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                          |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                          |

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
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
