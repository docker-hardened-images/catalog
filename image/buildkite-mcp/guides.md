## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Buildkite MCP Server image

The official Buildkite MCP Server connects AI tools directly to the Buildkite API, enabling AI agents, assistants, and
chatbots to query pipelines, inspect builds and jobs, read job logs, and review test runs through the Model Context
Protocol.

### Prerequisites

Before using the Buildkite MCP Server, you'll need:

1. **Buildkite Account**: An active Buildkite account with access to the organizations and pipelines you want to query.
1. **API Access Token**: A Buildkite API access token with the REST API scopes your workflow needs (for example
   `read_builds`, `read_pipelines`, `read_organizations`). See the upstream
   [API Access Tokens](https://buildkite.com/user/api-access-tokens) page to create one.

### Configuration

#### Claude Desktop Configuration

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "buildkite": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "BUILDKITE_API_TOKEN=your-api-token",
        "dhi.io/buildkite-mcp:<tag>"
      ]
    }
  }
}
```

#### Environment Variables

The server is configured through the following environment variables:

| Variable              | Description                                                 | Required |
| --------------------- | ----------------------------------------------------------- | -------- |
| `BUILDKITE_API_TOKEN` | Buildkite API access token used for authentication.         | Yes      |
| `BUILDKITE_BASE_URL`  | Base URL of the Buildkite API. Defaults to the SaaS API.    | No       |
| `BUILDKITE_TOOLSETS`  | Comma-separated list of toolsets to enable.                 | No       |
| `BUILDKITE_READ_ONLY` | Restricts the server to read-only tools when set to `true`. | No       |
| `HTTP_LISTEN_ADDR`    | Address used by HTTP mode. Defaults to `localhost:3000`.    | No       |

### Running the Server

The image runs the server in `stdio` transport mode by default, which is how MCP clients communicate with it:

```bash
docker run --rm -i \
  -e BUILDKITE_API_TOKEN=your-api-token \
  dhi.io/buildkite-mcp:<tag>
```

To run the streamable HTTP transport instead, override the default command with `http`. By default the server listens on
`localhost:3000`, which is not reachable from outside the container, so set `HTTP_LISTEN_ADDR` to bind to all
interfaces:

```bash
docker run --rm -p 3000:3000 \
  -e BUILDKITE_API_TOKEN=your-api-token \
  -e HTTP_LISTEN_ADDR=0.0.0.0:3000 \
  dhi.io/buildkite-mcp:<tag> http
```

The MCP endpoint is served at `http://localhost:3000/mcp`. A health check is available at
`http://localhost:3000/health`.

To connect Claude Desktop to the running HTTP server, add the following entry to `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "buildkite-http": {
      "type": "streamable-http",
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

For Cursor or VS Code, add the equivalent entry to `.cursor/mcp.json` or `.vscode/mcp.json`:

```json
{
  "servers": {
    "buildkite-http": {
      "type": "streamable-http",
      "url": "http://localhost:3000/mcp"
    }
  }
}
```

### Available Capabilities

The Buildkite MCP Server exposes the Buildkite API to AI tooling, including:

- **Pipelines**: List and inspect pipelines and their configuration.
- **Builds**: Query builds, their state, and metadata.
- **Jobs**: Inspect jobs within a build and retrieve job logs.
- **Tests**: Review test runs and analyze failures via Test Engine.
- **Organizations and users**: Read organization and access details available to the token.

### Security Best Practices

1. **Token Scopes**: Grant only the minimum REST API scopes the token needs.
1. **Token Storage**: Store the token securely using environment variables or a secrets manager, not in source control.
1. **Read-Only Access**: Prefer read scopes when the workflow does not require write access.
1. **Token Rotation**: Rotate API access tokens regularly.

## Additional Resources

- [Buildkite MCP Server](https://github.com/buildkite/buildkite-mcp-server)
- [Buildkite MCP Server documentation](https://buildkite.com/docs/apis/mcp-server)
- [Buildkite REST API documentation](https://buildkite.com/docs/apis/rest-api)
- [Model Context Protocol](https://modelcontextprotocol.io/)

## Non-hardened images vs. Docker Hardened Images

The Docker Hardened Image runs the server as a nonroot user and uses `/server/buildkite-mcp-server` as its entry point.
For compatibility with upstream images and scripts, `/ko-app/buildkite-mcp-server` is a symlink to the same binary. The
image explicitly uses `stdio` as its default command, which matches the upstream server's default transport behavior.

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

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

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
