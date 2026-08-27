# How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a memcached instance

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run -d -p 127.0.0.1:11211:11211 dhi.io/memcached:<tag>
```

## Common memcached use cases

### Basic caching server

Run memcached as a standalone caching server with custom memory allocation.

```bash
# Start memcached with 256MB memory and 2048 max connections
docker run -d --name memcached-cache \
  -p 127.0.0.1:11211:11211 \
  dhi.io/memcached:<tag> \
  -m 256 -c 2048 -v

# Verify it's running and test basic operations
echo "stats" | nc localhost 11211 | grep -E "version|limit_maxbytes|max_connections"

# Set a test value
printf "set testkey 0 900 5\r\nhello\r\n" | nc localhost 11211

# Get the value back
printf "get testkey\r\n" | nc localhost 11211
```

### Session storage for web applications

Use memcached for session management in a web application stack.

```bash
# Create application network
docker network create app-network

# Start memcached for session storage
docker run -d --name memcached-sessions \
  --network app-network \
  dhi.io/memcached:<tag> \
  -m 512 -c 4096 -I 10m

# Verify from another container on the same network
docker run --rm --network app-network busybox \
  sh -c 'echo "stats" | nc memcached-sessions 11211 | grep max_connections'
```

### Database query caching

Deploy memcached to cache database query results and reduce database load.

```bash
# Create network for database and memcached
docker network create db-cache-network

# Start memcached for database caching with resource limits
docker run -d --name memcached-db-cache \
  --network db-cache-network \
  --memory="1g" \
  --cpus="2.0" \
  dhi.io/memcached:<tag> \
  -m 768 -c 8192 -I 5m

# Verify memcached settings
docker run --rm --network db-cache-network busybox \
  sh -c 'echo "stats" | nc memcached-db-cache 11211 | grep limit_maxbytes'
```

### Multi-stage Dockerfile integration

Memcached DHI images do NOT provide dev variants. For build stages that require shell access and package managers, use
standard Docker Official memcached images.

```dockerfile
# syntax=docker/dockerfile:1
# Build stage - Use standard memcached image (has shell and package managers)
FROM memcached:1.6.39-alpine AS builder

USER root

# Install configuration tools
RUN apk add --no-cache curl bash jq

# Create configuration
RUN mkdir -p /app/config && \
    echo '{"cache_strategy": "lru", "max_memory_mb": 256, "max_connections": 2048}' > /app/config/memcached-config.json && \
    chown -R 11211:11211 /app

# Runtime stage - Use Docker Hardened memcached
FROM dhi.io/memcached:<tag> AS runtime

# Copy configuration from builder
COPY --from=builder --chown=memcached:memcached /app/config /app/config

# Memcached configuration
CMD ["-m", "256", "-c", "2048", "-I", "5m", "-v"]
```

Build and run:

```bash
docker build -t my-memcached-app .

docker run -d --name my-memcached \
  -p 127.0.0.1:11211:11211 \
  my-memcached-app

echo "stats" | nc localhost 11211 | grep -E "version|limit_maxbytes|max_connections"
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official Memcached           | Docker Hardened Memcached                           |
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

```bash
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-image \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/memcached:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

**Note:** Memcached DHI does NOT provide dev variants. For build stages requiring shell access or package managers, use
standard Docker Official memcached images (such as `memcached:alpine` or `memcached:bookworm`).

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                   |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Memcached DHI has no dev variants - use standard memcached images for build stages.                                   |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                  |
| Multi-stage build  | Use standard memcached images (with shell/package managers) for build stages and Docker Hardened memcached for runtime.                                                                     |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                          |
| Ports              | Non-dev hardened images run as a nonroot user by default. Memcached default port 11211 is not privileged and works without issues.                                                          |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use standard memcached images in build stages to run shell commands and then copy artifacts to the runtime stage.  |

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

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
