## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this mapbox-mcp image

The Mapbox MCP Server provides geospatial intelligence through the Model Context Protocol. It gives AI applications
access to Mapbox APIs for geocoding, points-of-interest search, multi-modal directions, travel-time matrices, route
optimization, map matching, isochrones, static map images, and offline geospatial calculations.

The server is built on Node.js and communicates over stdio transport by default, which is the standard MCP transport
used by desktop clients such as Claude Desktop and Cursor.

### Run the Mapbox MCP Server container

The server communicates over stdio, so the container must be launched with `-i` (interactive) to keep stdin open. The
`--rm` flag removes the container when the MCP client disconnects.

To print the available options:

```bash
docker run --rm dhi.io/mapbox-mcp:0 --help
```

To run the server for use by an MCP client:

```bash
docker run --rm -i \
  -e MAPBOX_ACCESS_TOKEN=your-access-token \
  dhi.io/mapbox-mcp:0
```

### Prerequisites

Before using the Mapbox MCP Server, you'll need:

1. **Mapbox Access Token**: Obtain an access token from [Mapbox](https://account.mapbox.com/access-tokens/)
1. **API Access**: Ensure your token has the scopes and rate limits appropriate for your use case

### Configure an MCP client

#### Claude Desktop

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "mapbox": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "MAPBOX_ACCESS_TOKEN=your-access-token",
        "dhi.io/mapbox-mcp:0"
      ]
    }
  }
}
```

#### Environment Variables

The server requires the following environment variables:

- `MAPBOX_ACCESS_TOKEN` (required): Your Mapbox access token

### Available Tools

The Mapbox MCP Server provides the following capabilities:

- **Geocoding**: Convert addresses and place names to coordinates and back (forward and reverse geocoding)
- **POI search**: Search for points of interest and place categories
- **Directions**: Compute multi-modal routes for driving, walking, and cycling
- **Matrix**: Calculate travel-time and distance matrices between many points
- **Optimization**: Solve route optimization problems
- **Map matching**: Snap GPS traces to the road network
- **Isochrones**: Generate reachability polygons for a given travel time or distance
- **Static maps**: Render static map images
- **Geospatial calculations**: Perform offline operations such as area, distance, buffering, and intersection

### Example Use Cases

**Forward Geocoding**

```
Query: "What are the coordinates of the Empire State Building?"
Server geocodes the place name and returns its coordinates
```

**Directions**

```
Query: "Give me driving directions from downtown San Francisco to the airport"
Server computes a route and returns the steps, distance, and duration
```

**Isochrones**

```
Query: "Show the area reachable within a 15-minute drive of this address"
Server generates an isochrone polygon for the requested travel time
```

**POI Search**

```
Query: "Find coffee shops near these coordinates"
Server searches for points of interest and returns matching places
```

### Security Best Practices

1. **Token Security**: Store access tokens securely using environment variables or secrets management
1. **Scope Minimization**: Use tokens scoped to only the APIs your workload needs
1. **Rate Limiting**: Monitor API usage to stay within your account's rate limits
1. **Token Rotation**: Rotate access tokens periodically and revoke unused tokens

## Additional Resources

- [Mapbox Documentation](https://docs.mapbox.com/)
- [Mapbox MCP Server GitHub](https://github.com/mapbox/mcp-server)
- [Model Context Protocol](https://modelcontextprotocol.io/)

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Mapbox MCP             | Docker Hardened Mapbox MCP                          |
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
docker run --rm -it --pid container:my-mapbox-mcp \
  --mount=type=image,source=dhi.io/busybox:1,destination=/dbg,ro \
  --entrypoint /dbg/bin/sh \
  dhi.io/mapbox-mcp:<tag>
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

| Item               | Migration note                                                                                                                                                                                                                                                   |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                        |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                        |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                       |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                           |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                               |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Mapbox MCP runs over stdio by default. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                      |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                      |

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
