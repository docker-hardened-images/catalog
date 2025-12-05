## How to use this image

Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
organization. To mirror the repository, select either **Mirror to repository** or **View in repository** > **Mirror to
repository**, and then follow the on-screen instructions.

## Start a Traefik instance

Traefik requires configuration to function. Create a configuration file and dynamic routing rules:

```
# Create directory structure
mkdir -p traefik/config/dynamic

# Create static configuration
cat > traefik/traefik.yml <<'EOF'
# Entry points
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

# File provider for dynamic configuration
providers:
  file:
    directory: "/config/dynamic"
    watch: true

# API and dashboard
api:
  dashboard: true
  insecure: true
EOF

# Create basic routing configuration
cat > traefik/config/dynamic/routes.yml <<'EOF'
http:
  routers:
    webapp:
      rule: "Host(`app.localhost`)"
      service: webapp-service
      entryPoints:
        - web

  services:
    webapp-service:
      loadBalancer:
        servers:
          - url: "http://nginx:8080"
EOF
```

Run Traefik with the configuration:

```
# Create backend network
docker network create traefik-net

# Start Traefik
docker run -d --name traefik \
  --network traefik-net \
  -p 8081:8080 \
  -p 81:80 \
  -p 443:443 \
  -v $PWD/traefik/traefik.yml:/etc/traefik/traefik.yml:ro \
  -v $PWD/traefik/config/dynamic:/config/dynamic:ro \
  <your-namespace>/dhi-traefik:<tag>
```

### Start a backend service

```
docker run -d --name nginx \
--network traefik-net \
<your-namespace>/dhi-nginx:<tag>-alpine<tag>
```

### Verify the setup

```
# Check containers are running
docker ps

# Check Traefik logs
docker logs traefik

# Test routing to nginx backend
curl -H "Host: app.localhost" http://localhost:81

# Access dashboard in browser
echo "Dashboard: http://localhost:8081/dashboard/"
```

You should see the nginx welcome page when testing the routing, and the Traefik dashboard should be accessible in your
browser at http://localhost:8081/dashboard/.

Note on ports: This example uses non-privileged ports (81 and 8081) which work reliably with the nonroot user (UID
65532\) across all environments. You can also use standard ports 80 and 8080 on Docker Engine 20.10+ and recent Docker
Desktop versions.

## Common Traefik use cases

### Basic reverse proxy with multiple services

Configure Traefik to route traffic to multiple backend services using file-based configuration.

```
# Step 1: Clean up previous example
docker rm -f traefik nginx nginx-backend api-backend backend backend-1 backend-2 backend-3 2>/dev/null || true
rm -f traefik/config/dynamic/*.yml  

# Step 2: Create configuration structure (if needed)
mkdir -p traefik/config/dynamic

# Step 3: Create static configuration
cat > traefik/traefik.yml <<'EOF'
entryPoints:
  web:
    address: ":80"

providers:
  file:
    directory: "/config/dynamic"
    watch: true

api:
  dashboard: true
  insecure: true
EOF

# Step 4: Create dynamic routing configuration for multiple services
cat > traefik/config/dynamic/services.yml <<'EOF'
http:
  routers:
    webapp:
      rule: "Host(`app.localhost`)"
      service: webapp-service
      entryPoints:
        - web

    api-router:
      rule: "Host(`api.localhost`)"
      service: api-service
      entryPoints:
        - web

  services:
    webapp-service:
      loadBalancer:
        servers:
          - url: "http://nginx-backend:8080"

    api-service:
      loadBalancer:
        servers:
          - url: "http://api-backend:8080"
EOF

# Step 5: Create network (ignore if exists)
docker network create traefik-net 2>/dev/null || true

# Step 6: Start Traefik
docker run -d --name traefik \
  --network traefik-net \
  -p 81:80 \
  -p 8081:8080 \
  -v $PWD/traefik/traefik.yml:/etc/traefik/traefik.yml:ro \
  -v $PWD/traefik/config/dynamic:/config/dynamic:ro \
 <your-namespace>/dhi-traefik:<tag>

# Step 7: Start backend services
docker run -d --name nginx-backend \
  --network traefik-net \
  <your-namespace>/dhi-nginx:<tag>-alpine<tag>

docker run -d --name api-backend \
  --network traefik-net \
  <your-namespace>/dhi-nginx:<tag>-alpine<tag>

# Step 8: Wait for containers to start
sleep 3

# Step 9: Verify setup
echo "=== Checking containers ==="
docker ps | grep -E "traefik|nginx-backend|api-backend"

echo ""
echo "=== Testing routing ==="
curl -H "Host: app.localhost" http://localhost:81
echo ""
echo "---"
curl -H "Host: api.localhost" http://localhost:81

echo ""
echo "=== Dashboard available at ==="
echo "http://localhost:8081/dashboard/"
```

## Load balancing with health checks

Configure Traefik to load balance traffic across multiple backend instances with health monitoring.

```
# Step 1: Clean up previous example
docker rm -f traefik nginx-backend api-backend backend-1 backend-2 backend-3 2>/dev/null || true
rm -f traefik/config/dynamic/*.yml

# Step 2: Create static configuration
cat > traefik/traefik.yml <<'EOF'
entryPoints:
  web:
    address: ":80"

providers:
  file:
    directory: "/config/dynamic"
    watch: true

api:
  dashboard: true
  insecure: true  
EOF

# Step 3: Create load balancing configuration with health checks
cat > traefik/config/dynamic/loadbalancer.yml <<'EOF'
http:
  routers:
    api-lb:
      rule: "Host(`api.localhost`)"
      service: api-loadbalanced
      entryPoints:
        - web

  services:
    api-loadbalanced:
      loadBalancer:
        servers:
          - url: "http://backend-1:80"
          - url: "http://backend-2:80"
          - url: "http://backend-3:80"
        healthCheck:
          path: /
          interval: "10s"
          timeout: "3s"
EOF

# Step 4: Start Traefik
docker run -d --name traefik \
  --network traefik-net \
  -p 81:80 \
  -p 8081:8080 \
  -v $PWD/traefik/traefik.yml:/etc/traefik/traefik.yml:ro \
  -v $PWD/traefik/config/dynamic:/config/dynamic:ro \
  <your-namespace>/dhi-traefik:<tag>

# Step 5: Start multiple backend instances
for i in 1 2 3; do
  docker run -d --name backend-$i \
    --network traefik-net \
    traefik/whoami
done

# Step 6: Wait for containers to start
sleep 3

# Step 7: Verify load balancing (you'll see different hostnames!)
for i in {1..6}; do
  curl -H "Host: api.localhost" http://localhost:81 | grep Hostname
  echo "---"
done
```

## Multi-stage Dockerfile integration

Traefik DHI images do NOT provide dev variants. For build stages that require shell access and package managers, use
standard Docker Official Traefik images.

```
# syntax=docker/dockerfile:1
# Build stage - Use standard Traefik image (has shell and package managers)
FROM traefik:3.5.3 AS builder

USER root

# Create custom configuration
RUN mkdir -p /app/config /app/dynamic && \
    apk add --no-cache bash yq

# Create static configuration
RUN cat > /app/config/traefik.yml <<'EOF'
entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  file:
    directory: "/config/dynamic"
    watch: true

certificatesResolvers:
  letsencrypt:
    acme:
      email: admin@example.com
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web

api:
  dashboard: true
EOF

# Create dynamic configuration
RUN cat > /app/dynamic/middleware.yml <<'EOF'
http:
  middlewares:
    security-headers:
      headers:
        customResponseHeaders:
          X-Frame-Options: "DENY"
          X-Content-Type-Options: "nosniff"
        sslRedirect: true
EOF

RUN chown -R 65532:65532 /app

# Runtime stage - Use Docker Hardened Traefik
FROM <your-namespace>/dhi-traefik:<tag> AS runtime

# Copy configuration from builder
COPY --from=builder --chown=traefik:traefik /app/config/traefik.yml /etc/traefik/traefik.yml
COPY --from=builder --chown=traefik:traefik /app/dynamic /config/dynamic

EXPOSE 80 443 8080
```

## Non-hardened images vs Docker Hardened Images

Key differences | Feature | Docker Official Traefik | Docker Hardened Traefik |
|---------|------------------------|------------------------| | Security | Standard base with common utilities |
Minimal, hardened base with security patches | | Shell access | Full shell (bash/sh) available | No shell in runtime
variants | | Package manager | apt/apk available | No package manager in runtime variants | | User | Runs as root by
default | Runs as nonroot user (UID 65532) | | Attack surface | Larger due to additional utilities | Minimal, only
essential components | | Debugging | Traditional shell debugging | Use Docker Debug or Image Mount for troubleshooting |

## Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- Docker Debug to attach to containers
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
docker run --rm -it --pid container:my-traefik \
  --mount=type=image,source=<your-namespace>/dhi-busybox,destination=/dbg,ro \
  <your-namespace>/dhi-traefik:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the FROM image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user (UID 65532)
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item | Migration note | |------|---------------| | Base image | Replace your base images in your Dockerfile with a
Docker Hardened Image. | | Package management | Non-dev images, intended for runtime, don't contain package managers.
Traefik DHI has no dev variants - use standard Traefik images for build stages. | | Non-root user | By default, non-dev
images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the
nonroot user. | | Multi-stage build | Use standard Traefik images (with shell/package managers) for build stages and
Docker Hardened Traefik for runtime. | | TLS certificates | Docker Hardened Images contain standard TLS certificates by
default. There is no need to install TLS certificates. | | Ports | Non-dev hardened images run as a nonroot user by
default. Traefik default ports 80, 443, and 8080 are not privileged (except 80 and 443 in some contexts - see Privileged
ports section below). | | Entry point | Docker Hardened Images may have different entry points than images such as
Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary. | | No
shell | By default, non-dev images, intended for runtime, don't contain a shell. Use standard Traefik images in build
stages to run shell commands and then copy artifacts to the runtime stage. |

The following steps outline the general migration process.

**1. Find hardened images for your app.**

A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

**2. Update the base image in your Dockerfile.**

Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
framework images, this is typically going to be an image tagged as dev because it has the tools needed to install
packages and dependencies.

**3. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as dev, your final
runtime stage should use a non-dev image variant.

**4. Install additional packages**

Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to install
additional packages in your Dockerfile. Inspect the image variants to identify which packages are already installed.

Only images tagged as dev typically have package managers. You should use a multi-stage Dockerfile to install the
packages. Install the packages in the build stage that uses a dev image. Then, if needed, copy any necessary artifacts
to the runtime stage that uses a non-dev image.

For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
install packages.

## Troubleshoot migration

The following are common issues that you may encounter during migration.

**General debugging**

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use Docker Debug to attach to these containers. Docker
Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that
only exists during the debugging session.

**Permissions**

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user. You may need to copy files to different directories or change permissions so your
application running as the nonroot user can access them.

**Privileged ports**

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

**Note for Traefik**: Traefik commonly uses ports 80 and 443. In Docker Engine 20.10+, these will work with the nonroot
user. For older versions or Kubernetes, consider using ports 8080 and 8443 inside the container and mapping them to 80
and 443 on the host.

**No shell**

By default, image variants intended for runtime don't contain a shell. Use dev images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

**Entry point**

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
