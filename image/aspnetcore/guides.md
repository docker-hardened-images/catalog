## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this ASP.NET Core image

This Docker Hardened ASP.NET Core image includes the ASP.NET Core runtime in a minimal, security-hardened package:

- **ASP.NET Core runtime**: Complete runtime for running .NET web applications
- **dotnet CLI**: Command-line interface for running .NET applications (not building)
- **TLS certificates**: Pre-installed CA certificates for secure connections
- **Container optimizations**: Pre-configured for non-root execution on port 8080
- **Security hardening**: No shell, no package manager, minimal attack surface

## Start an ASP.NET Core instance

Run the following command and replace `<tag>` with the image variant you want to run:

```bash
docker run --rm dhi.io/aspnetcore:<tag> dotnet --info
```

## Common ASP.NET Core use cases

### Run an ASP.NET Core application

Run your ASP.NET Core application directly from the container. Note that the default port is 8080 for non-root
compatibility:

```bash
docker run -p 8080:8080 dhi.io/aspnetcore:<tag> dotnet /app/myapp.dll
```

### Build and run a simple web API

Since DHI runtime images don't include build tools, use a multi-stage approach:

```bash
# Create a new web API project using DHI's SDK
docker run -v $(pwd):/app -w /app dhi.io/dotnet:8-sdk \
  dotnet new webapi -n MyApi --no-https

# Build the application using DHI's SDK
docker run -v $(pwd):/app -w /app dhi.io/dotnet:8-sdk \
  dotnet publish MyApi -c Release -o ./published

# Run with DHI runtime (note: this is a web API, so it needs proper setup)
docker run -v $(pwd)/published:/app -p 8080:8080 dhi.io/aspnetcore:8 \
  dotnet /app/MyApi.dll
```

### Multi-stage build for production

Use DHI's SDK for building and DHI runtime for production:

```docker
# Build stage
FROM dhi.io/dotnet:8-sdk AS builder
WORKDIR /src
COPY ["MyApp.csproj", "."]
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM dhi.io/aspnetcore:8
WORKDIR /app
COPY --from=builder /app/publish .
USER 1001
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

## Docker Official Images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official ASP.NET Core        | Docker Hardened ASP.NET Core                        |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |
| Base OS         | Various Alpine/Debian versions      | Hardened Alpine 3.22 or Debian 13 base              |

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

```bash
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-aspnet-app \\
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \\
  dhi.io/aspnetcore:<tag> /dbg/bin/sh
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

| Item                  | Migration note                                                                                                                                                                                                                                                                                                |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image            | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                     |
| Package management    | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                                     |
| Non-root user         | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                    |
| Multi-stage build     | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                        |
| TLS certificates      | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                            |
| Ports                 | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Configure your [ASP.NET](http://asp.net/) Core application to use ports above 1024. |
| Entry point           | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                   |
| No shell              | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                   |
| ASPNETCORE_HTTP_PORTS | The default HTTP port is set to 8080 via the ASPNETCORE_HTTP_PORTS environment variable. Adjust your application configuration if it expects port 80.                                                                                                                                                         |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   [ASP.NET](http://asp.net/) Core images are available in versions 6, 8, and 9.

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
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Configure your
[ASP.NET](http://asp.net/) Core applications to listen on ports 8080, 8443, or other ports above 1024.

### No shell

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

### [ASP.NET](http://asp.net/) Core-specific considerations

### Port configuration

[ASP.NET](http://asp.net/) Core applications in .NET 8+ use the `ASPNETCORE_HTTP_PORTS` environment variable (default:
8080\) instead of the older `ASPNETCORE_URLS`. For .NET 6/7 applications, you may need to set:

```docker
ENV ASPNETCORE_URLS=http://+:8080
```

### Static files and wwwroot

Ensure the wwwroot directory for static files is readable by the nonroot user:

```docker
COPY --chown=1001:1001 wwwroot ./wwwroot
```

### Blazor and SignalR applications

Applications using SignalR (including Blazor Server) may require additional environment configuration:

```docker
ENV ASPNETCORE_FORWARDEDHEADERS_ENABLED=true
```
