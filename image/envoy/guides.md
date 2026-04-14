## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Envoy image

This Docker Hardened Envoy image includes the complete Envoy proxy in a minimal, security-hardened package:

- **Envoy proxy**: High-performance L7 proxy with advanced load balancing and routing capabilities
- **Built-in extensions**: Core filters, listeners, and transport sockets for common use cases
- **Observability tools**: Metrics, tracing, and logging capabilities built-in
- **TLS certificates**: Pre-installed CA certificates for secure upstream connections
- **Security hardening**: Minimal attack surface with only essential components included

Unlike some other DHI images where runtime variants contain only the main binary, the Envoy runtime image includes all
necessary components for production deployments. This design decision delivers maximum operational flexibility:

- Service mesh deployments require comprehensive proxy capabilities
- Load balancing operations need all built-in filters and extensions
- Observability features are essential for production monitoring
- This bundling provides a complete proxy solution in one security-hardened package

This approach aligns with real-world production use cases where Envoy operations require more than just the basic proxy
binary.

## Start an Envoy instance

Run the following command and replace `<tag>` with the image variant you want to run.

**Note**: Envoy requires a configuration file to define its behavior. The basic command below will fail without a
configuration. See the use cases below for working examples.

```bash
docker run -p 9902:9902 -p 10000:10000 dhi.io/envoy:<tag>
```

## Common Envoy use cases

### Validate your configuration

Before running Envoy, always validate your configuration file. First, create a minimal working configuration:

```bash
# Create a minimal Envoy configuration
cat > envoy.yaml << 'EOF'
admin:
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9902

static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 10000
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          route_config:
            name: local_route
            virtual_hosts:
            - name: backend
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  cluster: example_cluster
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

  clusters:
  - name: example_cluster
    connect_timeout: 0.25s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: example_cluster
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: example.com
                port_value: 80
EOF
```

Now validate the configuration:

```bash
docker run --rm -v $(pwd)/envoy.yaml:/tmp/envoy.yaml:ro \
  dhi.io/envoy:<tag> \
  envoy --mode validate --config-path /tmp/envoy.yaml
```

### Basic HTTP proxy

Run Envoy with the validated configuration:

```bash
# Run in background
docker run -d --name my-envoy -p 9902:9902 -p 10000:10000 \
  dhi.io/envoy:<tag> \
  envoy --config-yaml "$(cat envoy.yaml)"
```

Test that it's working:

```bash
# Check admin interface
curl http://localhost:9902/server_info

# Test the proxy (forwards requests to example.com)
curl http://localhost:10000
```

Stop and remove when done:

```bash
docker stop my-envoy && docker rm my-envoy
```

### Load balancer for multiple backends

Create a load balancer configuration that distributes traffic across multiple backends:

```bash
# Create load balancer configuration
cat > envoy-lb.yaml << 'EOF'
admin:
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 9902

static_resources:
  listeners:
  - name: listener_0
    address:
      socket_address:
        address: 0.0.0.0
        port_value: 10000
    filter_chains:
    - filters:
      - name: envoy.filters.network.http_connection_manager
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.network.http_connection_manager.v3.HttpConnectionManager
          stat_prefix: ingress_http
          route_config:
            name: local_route
            virtual_hosts:
            - name: local_service
              domains: ["*"]
              routes:
              - match:
                  prefix: "/"
                route:
                  cluster: backend_cluster
          http_filters:
          - name: envoy.filters.http.router
            typed_config:
              "@type": type.googleapis.com/envoy.extensions.filters.http.router.v3.Router

  clusters:
  - name: backend_cluster
    connect_timeout: 0.25s
    type: STRICT_DNS
    lb_policy: ROUND_ROBIN
    load_assignment:
      cluster_name: backend_cluster
      endpoints:
      - lb_endpoints:
        - endpoint:
            address:
              socket_address:
                address: backend1.example.com
                port_value: 80
        - endpoint:
            address:
              socket_address:
                address: backend2.example.com
                port_value: 80
EOF
```

Validate and run:

```bash
# Validate configuration
docker run --rm -v $(pwd)/envoy-lb.yaml:/tmp/envoy-lb.yaml:ro \
  dhi.io/envoy:<tag> \
  envoy --mode validate --config-path /tmp/envoy-lb.yaml

# Run in background
docker run -d --name envoy-lb -p 9902:9902 -p 10000:10000 \
  dhi.io/envoy:<tag> \
  envoy --config-yaml "$(cat envoy-lb.yaml)"

# Check cluster status
curl http://localhost:9902/clusters
```

### Service mesh sidecar proxy

Use Envoy as a sidecar proxy in a multi-container setup with Docker Compose:

```bash
# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'
services:
  app:
    image: my-app:latest
    networks:
      - app-network

  envoy-sidecar:
    image: dhi.io/envoy:<tag>
    command: ["envoy", "--config-path", "/etc/envoy/envoy.yaml"]
    ports:
      - "8080:8080"
      - "9902:9902"
    volumes:
      - ./envoy-sidecar.yaml:/etc/envoy/envoy.yaml:ro
    networks:
      - app-network
    depends_on:
      - app

networks:
  app-network:
EOF

# Start the services
docker-compose up -d
```

### Monitoring and observability

Access Envoy's built-in admin interface for monitoring:

```bash
# Ensure Envoy is running
docker run -d --name my-envoy -p 9902:9902 -p 10000:10000 \
  dhi.io/envoy:<tag> \
  envoy --config-yaml "$(cat envoy.yaml)"

# Check stats endpoint
curl http://localhost:9902/stats

# View configuration
curl http://localhost:9902/config_dump

# Check cluster status
curl http://localhost:9902/clusters

# View server info
curl http://localhost:9902/server_info

# Stop and remove when done
docker stop my-envoy && docker rm my-envoy
```

## Docker Official Images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official Envoy               | Docker Hardened Envoy                               |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root or envoy user          | Runs as nonroot user (65532) for enhanced security  |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |
| Base OS         | Ubuntu/Alpine variants              | Hardened Debian 13 base                             |
| Configuration   | Flexible runtime modification       | Immutable configuration approach                    |

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
docker debug my-envoy
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-envoy \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/envoy:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user (65532)
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

| Item                     | Migration note                                                                                                                                                                                                                                                                           |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image               | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                |
| Package management       | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                              |
| Non-root user            | By default, non-dev images, intended for runtime, run as the nonroot user (65532). Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                       |
| Multi-stage build        | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                               |
| TLS certificates         | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                       |
| Ports                    | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Configure Envoy to use ports above 1024 in your configuration. |
| Entry point              | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                              |
| No shell                 | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                              |
| Configuration validation | DHI Envoy validates configuration at startup. Ensure your Envoy configuration files are syntactically correct before deployment.                                                                                                                                                         |
| File permissions         | Configuration files and certificates must be readable by the nonroot user. Use appropriate file permissions when mounting volumes.                                                                                                                                                       |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   Envoy images are available in versions 1.32.x, 1.33.x, 1.34.x, and 1.35.x.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Debian-based images, you can use `apt-get` to install packages.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

For Envoy-specific debugging, you can still access Envoy's built-in admin interface:

```bash
# Check Envoy status and configuration
curl http://localhost:9902/server_info
curl http://localhost:9902/stats
curl http://localhost:9902/config_dump

# View logs (if configured to output to stdout)
docker logs my-envoy
```

### Configuration issues

**Envoy requires configuration**: Unlike some services, Envoy cannot start without a valid configuration file. Always
provide a configuration using one of these methods:

```bash
# Method 1: Inline configuration (most reliable)
docker run dhi.io/envoy:<tag> envoy --config-yaml "$(cat config.yaml)"

# Method 2: Volume mounting
docker run -v $(pwd)/config.yaml:/etc/envoy/envoy.yaml:ro dhi.io/envoy:<tag>
```

**Configuration validation**: Always validate before deployment:

```bash
docker run --rm -v $(pwd)/envoy.yaml:/tmp/envoy.yaml:ro \
  dhi.io/envoy:<tag> \
  envoy --mode validate --config-path /tmp/envoy.yaml
```

### Container management

**Background execution**: For persistent deployments, use the `-d` flag and name your containers:

```bash
docker run -d --name my-envoy dhi.io/envoy:<tag> [command]

# Stop and remove when done
docker stop my-envoy && docker rm my-envoy
```

**Port conflicts**: Ensure ports 9902 and 10000 (or your custom ports) are not already in use:

```bash
# Check if ports are in use
netstat -tlnp | grep :9902
lsof -i :9902
```

### Permissions

By default image variants intended for runtime, run as the nonroot user (65532). Ensure that necessary files and
directories are accessible to the nonroot user. You may need to copy files to different directories or change
permissions so your application running as the nonroot user can access them.

For Envoy, this particularly affects:

- Configuration files (must be readable)
- Certificate files for TLS (must be readable)
- Log files (directory must be writable if logging to files)

```bash
# Ensure configuration is readable
chmod 644 envoy.yaml

# Ensure certificates are readable but secure
chmod 600 server.key
chmod 644 server.pem
chown 65532:65532 server.key server.pem
```

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Configure Envoy
listeners to use ports above 1024 in your configuration:

```yaml
# Instead of port 80, use port 8080
listeners:
- name: listener_0
  address:
    socket_address:
      address: 0.0.0.0
      port_value: 8080  # Use 8080 instead of 80
```

Then map to privileged ports externally:

```bash
docker run -p 80:8080 -p 443:8443 dhi.io/envoy:<tag>
```

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

### Volume mounting issues

If volume mounting fails or configurations aren't loaded:

1. **Use absolute paths**: `$(pwd)/envoy.yaml` instead of `./envoy.yaml`
1. **Check file permissions**: Files must be readable by the nonroot user (65532)
1. **Verify file exists**: Ensure the configuration file exists before mounting
1. **Use inline configuration as fallback**: The `--config-yaml "$(cat file.yaml)"` method is more reliable

```bash
# Debug volume mounting
docker run --rm -v $(pwd):/test alpine ls -la /test/envoy.yaml

# Alternative: Use inline configuration
docker run dhi.io/envoy:<tag> envoy --config-yaml "$(cat envoy.yaml)"
```

### Network connectivity issues

When Envoy can't reach upstream services:

1. **Check cluster configuration:** Verify hostnames and ports in your Envoy config
1. **Test connectivity:** Use Docker Debug to verify network connectivity
1. **DNS resolution:** Ensure service names resolve correctly within your container network

```bash
# Use Docker Debug to test connectivity
docker debug my-envoy
# Inside debug session:
nslookup backend.example.com
curl -v http://backend.example.com:8080/health
```
