## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use, update your
commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/wikipedia-mcp:<tag>`
- Mirrored image: `<your-namespace>/dhi-wikipedia-mcp:<tag>`

For the examples, use `docker login dhi.io` to authenticate to the registry before pulling the image.

## Getting Started with Wikipedia MCP Server

Wikipedia MCP Server provides Wikipedia search and article retrieval tools through the Model Context Protocol. It is
intended to run as an MCP server for clients that communicate over standard input and output.

### Run the Server

To run the server directly:

```bash
docker run --rm -i dhi.io/wikipedia-mcp:2
```

### Claude Desktop Configuration

Add the server to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "wikipedia": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "dhi.io/wikipedia-mcp:2"
      ]
    }
  }
}
```

### What's Included

The image includes the `wikipedia-mcp` console command and its Python runtime dependencies. For complete usage,
transport, and tool documentation, see the upstream project documentation at
https://github.com/Rudra-ravi/wikipedia-mcp.

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

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, update your container image reference to use the DHI repository
and tag that matches your workload.

| Item               | Migration note                                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| Image reference    | Replace non-hardened image references with `dhi.io/wikipedia-mcp:<tag>` or your mirrored repository.                                  |
| Package management | Runtime images do not include package managers. Use a `dev` variant for build stages that need package installation.                  |
| Non-root user      | Runtime images run as the nonroot user. Ensure mounted files are readable by that user.                                               |
| No shell           | Runtime images do not include a shell. Use Docker Debug or a `dev` variant when you need interactive inspection or shell-based tools. |

## Troubleshooting migration

### Debugging runtime containers

Runtime variants are intentionally minimal. Use Docker Debug when you need shell access or filesystem inspection:

```bash
docker debug <container-name>
```

### Using dev variants

Use a `dev` variant when a build stage needs a shell, package manager, or other development tools:

```dockerfile
FROM dhi.io/wikipedia-mcp:2-dev AS build
```

## Runtime troubleshooting

Runtime images run as `nonroot`, do not include a shell, and are intended to be debugged with Docker Debug rather than
with shell tools inside the container.

### General debugging

The hardened images intended for runtime do not contain a shell or debugging tools. Use Docker Debug to attach to the
container when you need a shell, common troubleshooting tools, or an ephemeral writable layer during the debugging
session.

### Permissions

Runtime variants run as the `nonroot` user. Make sure any required files and directories are readable and writable by
that user. You may need to copy files to a different location or adjust permissions so the application can access them.

### Privileged ports

Non-dev hardened images run as `nonroot`, so they cannot bind to privileged ports below 1024 in Kubernetes or in older
Docker Engine releases. Configure the application to listen on port 1025 or higher inside the container, even if you map
it to a lower port on the host.

### No shell

Runtime variants do not include a shell. Use `dev` images in build stages when you need shell commands, then copy the
required artifacts into the runtime stage. For interactive inspection, use Docker Debug.

### Entry point

Docker Hardened Images may use different entry points than Docker Official Images. Use `docker inspect` to check the
entry point and update your client or Dockerfile if needed.
