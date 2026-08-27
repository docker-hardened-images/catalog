## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a scrapegraph-mcp image

The image starts the ScrapeGraph MCP server over the stdio transport by default. MCP clients can launch it directly and
pass a ScrapeGraph API key through MCP configuration.

### Basic stdio usage

Use this image from an MCP client configuration:

```json
{
  "mcpServers": {
    "scrapegraph-mcp": {
      "command": "docker",
      "args": ["run", "--rm", "-i", "dhi.io/scrapegraph-mcp:<tag>"],
      "env": {
        "SGAI_API_KEY": "your-api-key"
      }
    }
  }
}
```

### HTTP transport

The upstream server can also run over HTTP at `/mcp`. Set `MCP_TRANSPORT=http`, bind the host port to loopback unless
you are intentionally exposing the MCP server, and pass each user's API key with the `X-API-Key` header from the MCP
client. The API key is checked by tools that call the ScrapeGraph API; it is not a server-level network access gate.

```bash
$ docker run -d --name scrapegraph-mcp -p 127.0.0.1:8000:8000 \
  -e MCP_TRANSPORT=http \
  dhi.io/scrapegraph-mcp:<tag>
```

Confirm the server is healthy, then point MCP HTTP clients at `http://localhost:8000/mcp`:

```bash
$ curl http://localhost:8000/health
{"status":"healthy","service":"scrapegraph-mcp"}
```

### Environment variables

| Variable                   | Description                                         | Default                                | Required |
| -------------------------- | --------------------------------------------------- | -------------------------------------- | -------- |
| `SGAI_API_KEY`             | ScrapeGraph API key for stdio clients.              | —                                      | No       |
| `SGAI_API_URL`             | Override the ScrapeGraph API base URL.              | `https://v2-api.scrapegraphai.com/api` | No       |
| `SGAI_TIMEOUT`             | Request timeout in seconds.                         | `120`                                  | No       |
| `MCP_TRANSPORT`            | Transport mode. Use `http` for remote HTTP serving. | `stdio`                                | No       |
| `HOST`                     | HTTP bind address when `MCP_TRANSPORT=http`.        | `0.0.0.0`                              | No       |
| `PORT`                     | HTTP port when `MCP_TRANSPORT=http`.                | `8000`                                 | No       |
| `SCRAPEGRAPH_API_BASE_URL` | Legacy alias for `SGAI_API_URL`.                    | —                                      | No       |
| `SGAI_TIMEOUT_S`           | Legacy alias for `SGAI_TIMEOUT`.                    | —                                      | No       |

## ScrapeGraph MCP tools

The server exposes tools for page scraping, structured extraction, AI-assisted search, asynchronous crawling, schema
generation, scheduled monitors, request history, and account credits. A ScrapeGraph API key is required when invoking
tools that call the ScrapeGraph API.

For tool parameters and advanced configuration, see the
[upstream project documentation](https://github.com/ScrapeGraphAI/scrapegraph-mcp).

## Non-hardened images vs. Docker Hardened Images

Both the upstream and hardened images default to stdio transport mode for local MCP usage. To run the HTTP transport,
set `MCP_TRANSPORT=http` as shown above.

The listed non-hardened image provides the console script at `/usr/local/bin/scrapegraph-mcp`. This image packages the
script at `/usr/bin/scrapegraph-mcp` and also provides `/usr/local/bin/scrapegraph-mcp` as a compatibility symlink.

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

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
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy any necessary artifacts to the runtime stage.                                                                                                                                    |

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

### Entry point

This image starts `scrapegraph-mcp` over stdio by default. If you override the command in Kubernetes or Docker Compose,
keep `-i` on the surrounding `docker run` command for stdio clients so MCP JSON-RPC messages can flow over stdin and
stdout.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.
