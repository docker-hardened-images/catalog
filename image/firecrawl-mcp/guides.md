## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Getting Started with Firecrawl MCP Server

The Firecrawl MCP Server provides web scraping, crawling, and content extraction capabilities through the Model Context
Protocol. It enables AI applications to extract structured data from websites and process web content.

### Prerequisites

Before using the Firecrawl MCP Server, you'll need:

1. **Firecrawl API Key**: Obtain an API key from [Firecrawl](https://firecrawl.dev/)
1. **API Access**: Ensure you have appropriate API rate limits for your use case

### Configuration

#### Claude Desktop Configuration

Add to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "firecrawl": {
      "command": "docker",
      "args": [
        "run",
        "--rm",
        "-i",
        "-e", "FIRECRAWL_API_KEY=your-api-key",
        "dhi.io/firecrawl-mcp"
      ]
    }
  }
}
```

#### Environment Variables

The server requires the following environment variables:

- `FIRECRAWL_API_KEY` (required): Your Firecrawl API key

### Running the Server

To run the server directly:

```bash
docker run --rm -i \
  -e FIRECRAWL_API_KEY=your-api-key \
  dhi.io/firecrawl-mcp
```

### Available Tools

The Firecrawl MCP Server provides the following capabilities:

- **Scrape pages**: Extract content from individual web pages
- **Crawl websites**: Perform deep crawls to discover and scrape multiple pages
- **Extract structured data**: Convert web content to structured formats (JSON, Markdown)
- **Handle dynamic content**: Process JavaScript-rendered pages
- **Content transformation**: Convert HTML to clean, readable formats

### Tool Parameters

**Scrape Tool:**

- `url` (required): The URL to scrape
- `formats` (optional): Output formats (markdown, html, json)
- `onlyMainContent` (optional): Extract only main content, removing navigation and ads
- `includeTags` (optional): Specific HTML tags to include
- `excludeTags` (optional): HTML tags to exclude

**Crawl Tool:**

- `url` (required): Starting URL for the crawl
- `maxDepth` (optional): Maximum crawl depth
- `limit` (optional): Maximum number of pages to crawl
- `allowedDomains` (optional): Restrict crawling to specific domains
- `excludePatterns` (optional): URL patterns to exclude

### Example Use Cases

**Single Page Scraping**

```
Query: "Scrape the content from https://example.com/article"
Server extracts and returns structured content
```

**Website Crawling**

```
Query: "Crawl https://docs.example.com and extract all documentation pages"
Server discovers and scrapes linked pages up to configured depth
```

**Structured Data Extraction**

```
Query: "Extract product information from this e-commerce page"
Server scrapes and structures product details, prices, and descriptions
```

**Content Monitoring**

```
Query: "Check for changes on the company blog homepage"
Server scrapes and compares content for updates
```

### Security Best Practices

1. **API Key Security**: Store API keys securely using environment variables or secrets management
1. **Rate Limiting**: Monitor API usage to stay within rate limits
1. **Respectful Crawling**: Configure appropriate crawl delays and limits
1. **Content Filtering**: Use filters to avoid scraping sensitive or private content
1. **Compliance**: Ensure web scraping complies with website terms of service and robots.txt

### Performance Tips

- Use `onlyMainContent: true` for faster, cleaner results
- Set appropriate `maxDepth` and `limit` values for crawls
- Leverage caching for frequently accessed content
- Monitor API quota usage through the Firecrawl dashboard

## Additional Resources

- [Firecrawl Documentation](https://docs.firecrawl.dev/)
- [Firecrawl MCP Server GitHub](https://github.com/firecrawl/firecrawl-mcp-server)
- [Model Context Protocol](https://modelcontextprotocol.io/)

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Firecrawl MCP          | Docker Hardened Firecrawl MCP                       |
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
docker run --rm -it --pid container:my-firecrawl-mcp \
  --mount=type=image,source=dhi.io/busybox:1,destination=/dbg,ro \
  --entrypoint /dbg/bin/sh \
  dhi.io/firecrawl-mcp:<tag>
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

| Item               | Migration note                                                                                                                                                                                                                                                             |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                  |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                 |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                         |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Firecrawl MCP default ports work without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                |

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
