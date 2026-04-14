## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this .NET image

This Docker Hardened .NET image provides secure, production-ready variants for both development and runtime scenarios:

Runtime variants include:

- .NET runtime for running compiled applications
- Essential libraries and dependencies
- Optimized for minimal attack surface

SDK variants (tagged with `-sdk`) include:

- Complete .NET SDK for building applications
- Package managers and development tools
- Build tools and compilers
- Shell access for development workflows

## Start a .NET application

Run the following command:

```bash
# Run a .NET application (runtime variant)
docker run --rm dhi.io/dotnet:<tag>

# Start an interactive development container (SDK variant)
docker run --rm -it --entrypoint bash dhi.io/dotnet:<tag>-sdk
```

To inspect the image configuration:

```bash
# Check entry point and user configuration
docker image inspect dhi.io/dotnet:8 --format='{{.Config.Entrypoint}}'
docker image inspect dhi.io/dotnet:8 --format='{{.Config.Cmd}}'
docker image inspect dhi.io/dotnet:8 --format='{{.Config.User}}'

# Compare image sizes
docker images | grep dotnet
```

## Common .NET use cases

### Build and run a .NET console application

Use a multi-stage Dockerfile to build your application with the SDK variant and run with the runtime variant:

```dockerfile
# Build stage using SDK variant
FROM dhi.io/dotnet:8-sdk AS build
WORKDIR /src
COPY *.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app

# Runtime stage using minimal runtime variant
FROM dhi.io/dotnet:8
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "YourApp.dll"]
```

Build and run commands:

```bash
docker build -t my-console-app .
docker run --rm my-console-app
```

### ASP.NET Core web application

For web applications, use the ASP.NET Core runtime from the separate DHI ASP.NET Core repository:

```dockerfile
# Build stage
FROM dhi.io/dotnet:8-sdk AS build
WORKDIR /src
COPY MyWebApp/*.csproj ./MyWebApp/
RUN dotnet restore MyWebApp/MyWebApp.csproj
COPY . .
RUN dotnet publish MyWebApp/MyWebApp.csproj -c Release -o /app

# Runtime stage for web apps
FROM dhi.io/aspnetcore:8
WORKDIR /app
COPY --from=build /app .
EXPOSE 8080
ENTRYPOINT ["dotnet", "MyWebApp.dll"]
```

Configure your ASP.NET Core application for nonroot user compatibility:

```csharp
// In Program.cs, ensure proper port configuration
var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

app.MapGet("/", () => "Hello World from DHI .NET Web App!");
app.MapGet("/health", () => new { status = "healthy", timestamp = DateTime.UtcNow });

// Use port 8080 (nonroot user compatible)
app.Run("http://0.0.0.0:8080");
```

Build and run commands:

```bash
docker build -t my-web-app .
docker run -d --name my-web-app -p 8080:8080 my-web-app

# Test endpoints
curl http://localhost:8080/
curl http://localhost:8080/health

# Clean up
docker stop my-web-app && docker rm my-web-app
```

### Development container with volume mounting

Mount your source code for live development:

```bash
# Start an interactive development environment
docker run --rm -it \
  -v $(pwd):/workspace \
  -w /workspace \
  dhi.io/dotnet:8-sdk \
  bash
```

Inside the container, you can run complete development workflows:

```bash
# Create a new project
dotnet new console -n MyApp
cd MyApp

# Add packages
dotnet add package Newtonsoft.Json

# Build and run
dotnet build
dotnet run

# Run tests
dotnet test

# Publish for production
dotnet publish -c Release -o ./publish
```

For quick development tasks without entering the container:

```bash
# Create a new project from outside the container
docker run --rm -v $(pwd):/workspace -w /workspace \
  dhi.io/dotnet:8-sdk \
  dotnet new web -n MyWebApp

# Build the project
docker run --rm -v $(pwd):/workspace -w /workspace \
  dhi.io/dotnet:8-sdk \
  dotnet build MyWebApp

# Create and run a simple console application
docker run --rm -v $(pwd):/workspace -w /workspace \
  dhi.io/dotnet:8-sdk \
  dotnet new console -n HelloWorld

docker run --rm -v $(pwd):/workspace -w /workspace \
  dhi.io/dotnet:8-sdk \
  dotnet run --project HelloWorld
```

### Running pre-built applications

Execute .NET CLI commands to run pre-built applications:

```bash
# Create and build a console application using SDK
docker run --rm -v $(pwd):/workspace -w /workspace \
  dhi.io/dotnet:8-sdk \
  dotnet new console -n MyApp

docker run --rm -v $(pwd):/workspace -w /workspace \
  dhi.io/dotnet:8-sdk \
  dotnet build MyApp

# Run the built application using runtime image (note the full path to the compiled DLL)
docker run --rm -v $(pwd):/workspace -w /workspace \
  dhi.io/dotnet:8 \
  dotnet MyApp/bin/Debug/net8.0/MyApp.dll
```

**Note**: When using `dotnet build`, the compiled DLL is placed in `bin/Debug/net8.0/` (or `bin/Release/net8.0/` for
release builds). When using `dotnet publish` in multi-stage builds, the DLL is copied directly to the specified output
directory (`/app` in the examples above), which is why the multi-stage examples work with just the DLL name.

### Kubernetes deployment

Deploy your .NET application to Kubernetes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dotnet-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: dotnet-app
  template:
    metadata:
      labels:
        app: dotnet-app
    spec:
      containers:
        - name: dotnet-app
          image: <your-namespace>/my-dotnet-app:latest
          ports:
            - containerPort: 8080
          env:
            - name: ASPNETCORE_ENVIRONMENT
              value: "Production"
            - name: ASPNETCORE_URLS
              value: "http://0.0.0.0:8080"
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            requests:
              memory: "128Mi"
              cpu: "100m"
            limits:
              memory: "256Mi"
              cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: dotnet-app-service
spec:
  selector:
    app: dotnet-app
  ports:
    - port: 80
      targetPort: 8080
  type: LoadBalancer
```

### Use Docker Compose

This is an example pattern for local development. This example cannot be run as-is and requires a complete application
setup:

```yaml
version: "3.8"
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ASPNETCORE_URLS=http://0.0.0.0:8080
    volumes:
      - ./logs:/app/logs
    depends_on:
      - db

  db:
    image: postgres:15
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

**Note**: This is provided as a reference pattern only. To use this, you would need:

- A working Dockerfile in your project root
- An ASP.NET Core application configured to connect to PostgreSQL
- Proper Entity Framework or database connection setup

## Docker Official Images vs. Docker Hardened Images

| Feature         | Docker Official .NET                | Docker Hardened .NET                                    |
| --------------- | ----------------------------------- | ------------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches            |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants, available in SDK variants |
| Package manager | apt/apk available                   | No package manager in runtime variants                  |
| User            | Runs as root by default             | Runtime variants run as nonroot user                    |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                      |
| Image size      | Larger (500MB-1.2GB)                | Smaller (200MB-800MB)                                   |
| CVEs            | May contain known vulnerabilities   | Zero known CVEs at publish time                         |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting     |
| Base OS         | Various Debian/Alpine versions      | Hardened Alpine 3.22 or Debian 13 base                  |
| Compliance      | Standard compliance                 | FIPS-compliant and STIG-certified variants available    |

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
# Start your application
docker run -d --name my-app dhi.io/dotnet:8

# Attach debugger
docker debug my-app
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-dotnet-app \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/dotnet:8 /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Runtime variants** are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

**Build-time variants** (SDK variants) typically include `-sdk` in the variant name and are intended for use in the
first stage of a multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications
- Include the complete .NET SDK toolchain

Available variants include:

- `8`: .NET 8 runtime only
- `8-sdk`: .NET 8 SDK for development and building
- `9`: .NET 9 runtime only
- `9-sdk`: .NET 9 SDK for development and building

For ASP.NET Core application, use the separate DHI ASP.NET Core repository:

- `dhi.io/aspnetcore:8`: ASP.NET Core 8 runtime
- `dhi.io/aspnetcore:9`: ASP.NET Core 9 runtime

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-SDK images, intended for runtime, don't contain package managers. Use package managers only in images with a `-sdk` tag.                                                                                                                                                                                                 |
| Non-root user      | By default, non-SDK images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `-sdk` tag for build stages and runtime images for runtime. For ASP.NET Core apps, use `dhi-aspnetcore` images for runtime.                                                                                                                                                                            |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-SDK hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-SDK images, intended for runtime, don't contain a shell. Use `-sdk` images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                               |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `-sdk` because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image.

   While intermediary stages will typically use images tagged as `-sdk`, your final runtime stage should use a runtime
   image variant.

1. **Install additional packages.**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `-sdk` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `-sdk` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-SDK image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

### Before and after migration

Before (using official images):

```dockerfile
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish -c Release -o /app

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

After (using DHI):

```dockerfile
FROM dhi.io/dotnet:8-sdk AS build
WORKDIR /src
COPY *.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app

FROM dhi.io/aspnetcore:8
WORKDIR /app
COPY --from=build /app .
EXPOSE 8080
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

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

Non-SDK hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `-sdk` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use
`docker image inspect` to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

### .NET-specific considerations

- Global tools: Global .NET tools should be installed during the build stage using the SDK image
- NuGet packages: All package restoration should happen in the SDK build stage
- Runtime dependencies: Ensure all required runtime libraries are present in the final runtime image
- Configurations: Use environment variables or configuration files that are accessible to the nonroot user
- File paths: When running applications with `dotnet build`, the DLL is located in `bin/Debug/net8.0/` or
  `bin/Release/net8.0/` subdirectories. When using `dotnet publish`, the DLL is placed in the specified output
  directory.
- Logging: Configure logging to write to stdout/stderr or to directories writable by the nonroot user
- Health checks: Implement health check endpoints for Kubernetes liveness and readiness probes
