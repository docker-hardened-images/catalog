## Prerequisite

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a MongoDB Exporter instance

Note: MongoDB Docker Hardened Images are AMD64-tagged images. When running on ARM-based systems using the
`--platform linux/amd64` flag, the images will run under emulation, which can significantly impact performance.

### Basic MongoDB Exporter instance

Before you run a MongoDB Exporter instance, ensure that you have MongoDB database instance up and running on your
system.

```
# 1. Create network
docker network create mongo-monitoring

# 2. Start MongoDB DHI
docker run -d \
  --name mongodb \
  --platform linux/amd64 \
  --network mongo-monitoring \
  dhi.io/mongodb:<tag>-dev \
  --bind_ip_all

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to start..."
sleep 15

# Verify MongoDB is running
docker exec mongodb mongosh --eval "db.version()"

# 3. Start MongoDB Exporter DHI
docker run -d \
  --name mongodb-exporter \
  --network mongo-monitoring \
  -p 9216:9216 \
  dhi.io/mongodb-exporter:<tag> \
  --mongodb.uri=mongodb://mongodb:27017

# Wait for exporter to connect
sleep 5

# 4. Verify it's working
curl -s http://localhost:9216/metrics | grep mongodb_up
# Expected output: mongodb_up{cluster_role="mongod"} 1
```

**Note:** This assumes that you have already mirrored the MongoDB DHI image repository from the catalog to your
organization. MongoDB DHI requires the `--bind_ip_all` flag to accept connections from other containers. The
`--bind_ip_all` flag makes MongoDB DHI container listen on 0.0.0.0 (all network interfaces).

### MongoDB Exporter with authentication

If your MongoDB instance requires authentication, provide credentials in the connection URI:

```bash
docker run -d \
  --name mongodb-exporter \
  -p 9216:9216 \
  dhi.io/mongodb-exporter:<tag> \
  --mongodb.uri=mongodb://admin:secure_password@mongodb:27017/admin
```

### Using environment variables

You can also configure MongoDB Exporter using environment variables:

```bash
docker run -d \
  --name mongodb-exporter \
  -p 9216:9216 \
  -e MONGODB_URI=mongodb://admin:secure_password@mongodb:27017/admin \
  dhi.io/mongodb-exporter:<tag>
```

Available environment variables:

- MONGODB_URI: MongoDB connection URI (e.g., mongodb://user:pass@host:27017/admin)
- MONGODB_USER: MongoDB username (alternative to including in URI)
- MONGODB_PASSWORD: MongoDB password (alternative to including in URI)
- WEB_LISTEN_ADDRESS: Address to listen on (default: :9216)
- WEB_TELEMETRY_PATH: Path for metrics (default: /metrics)

## Common Use Cases

### Complete monitoring setup with MongoDB

This example shows how to set up MongoDB with authentication and MongoDB Exporter for monitoring:

```bash
# 1. Create network and volume
docker network create mongo-monitoring
docker volume create mongodb_data

# 2. Start MongoDB without authentication
docker run -d \
  --name mongodb \
  --platform linux/amd64 \
  --network mongo-monitoring \
  -v mongodb_data:/data/db \
  dhi.io/mongodb:<tag>-dev \
  --bind_ip_all

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to start..."
sleep 15

# Verify MongoDB is running
docker exec mongodb mongosh --eval "db.version()"

# 3. Create admin user
docker exec mongodb mongosh --eval "
  db.getSiblingDB('admin').createUser({
    user: 'admin',
    pwd: 'secure_password',
    roles: [{role: 'root', db: 'admin'}]
  })
"

# 4. Enable authentication - Restart MongoDB
docker stop mongodb && docker rm mongodb

docker run -d \
  --name mongodb \
  --network mongo-monitoring \
  -p 27017:27017 \
  -v mongodb_data:/data/db \
  dhi.io/mongodb:<tag>-dev \
  --bind_ip_all \
  --auth

# Wait for MongoDB with authentication
echo "Waiting for MongoDB with authentication..."
sleep 15

# Verify authentication works
docker exec mongodb mongosh -u admin -p secure_password \
  --authenticationDatabase admin --eval "db.version()"

# 5. Start MongoDB Exporter
docker run -d \
  --name mongodb-exporter \
  --network mongo-monitoring \
  -p 9216:9216 \
  dhi.io/mongodb-exporter:<tag> \
  --mongodb.uri=mongodb://admin:secure_password@mongodb:27017/admin \
  --collector.dbstats \
  --collector.collstats

# Wait for exporter to connect
sleep 5

# 6. Verify metrics are being exported
curl -s http://localhost:9216/metrics | grep mongodb_up
# Expected output: mongodb_up{cluster_role="mongod"} 1
```

### Important Notes:

- Platform Requirement: MongoDB DHI currently only supports linux/amd64. On Apple Silicon Macs, always use
  `--platform linux/amd64`
- Network Binding: The `--bind_ip_all` flag is required for MongoDB to accept connections from other containers. Without
  it, MongoDB only binds to 127.0.0.1
- Wait Times: Allow sufficient time for MongoDB to start (15 seconds recommended) before attempting connections
- Authentication: Use `--auth` flag for simple auth setup, or config files for advanced scenarios

### Advanced configuration options

The MongoDB Exporter supports various command-line flags to customize its behavior:

```bash
docker run -d \
  --name mongodb-exporter \
  -p 9216:9216 \
  dhi.io/mongodb-exporter:<tag> \
  --mongodb.uri=mongodb://admin:secure_password@mongodb:27017/admin \
  --collector.dbstats \
  --collector.collstats \
  --collector.topmetrics \
  --collector.indexstats \
  --collector.replicasetstatus
```

**Common collectors:**

- `--collector.dbstats` - Database statistics
- `--collector.collstats` - Collection statistics
- `--collector.topmetrics` - Top command metrics
- `--collector.indexstats` - Index statistics
- `--collector.replicasetstatus` - Replica set status metrics

### Docker Compose example

Complete monitoring stack with MongoDB, MongoDB Exporter, and Prometheus:

```yaml
services:
  mongodb:
    image: dhi.io/mongodb:<tag>-dev
    container_name: mongodb
    command: --bind_ip_all --auth
    ports:
      - "27017:27017"
    environment:
      MONGO_INITDB_ROOT_USERNAME: admin
      MONGO_INITDB_ROOT_PASSWORD: password
    volumes:
      - mongodb_data:/data/db
    networks:
      - monitoring
    healthcheck:
      test: ["CMD", "mongosh", "-u", "admin", "-p", "password", "--authenticationDatabase", "admin", "--eval", "db.adminCommand('ping')"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  mongodb-exporter:
    image: dhi.io/mongodb-exporter:<tag>
    container_name: mongodb-exporter
    ports:
      - "9216:9216"
    command:
      - --mongodb.uri=mongodb://admin:password@mongodb:27017/admin
      - --collector.dbstats
      - --collector.collstats
      - --collector.topmetrics
    depends_on:
      mongodb:
        condition: service_healthy
    networks:
      - monitoring
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9216/metrics"]
      interval: 10s
      timeout: 5s
      retries: 3

  prometheus:
    image: dockerdevrel/dhi-prometheus:<tag>
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    depends_on:
      mongodb-exporter:
        condition: service_healthy
    networks:
      - monitoring

volumes:
  mongodb_data:
  prometheus_data:

networks:
  monitoring:
    driver: bridge
```

**prometheus.yml configuration:**

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'mongodb-exporter'
    static_configs:
      - targets: ['mongodb-exporter:9216']
    scrape_interval: 30s
```

### Accessing metrics

Once the MongoDB Exporter is running, you can access the metrics:

```bash
# View all metrics
curl http://localhost:9216/metrics

# Check MongoDB connectivity
curl -s http://localhost:9216/metrics | grep mongodb_up
# Should return: mongodb_up{cluster_role="mongod"} 1

# Check exporter health
curl http://localhost:9216/metrics | grep mongodb_exporter_build_info

# View database statistics
curl -s http://localhost:9216/metrics | grep mongodb_db
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | MongoDB Exporter (Official)         | Docker Hardened MongoDB Exporter                    |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | package manager available           | No package manager in runtime variants              |
| User            | Runs as specific user               | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |
| Vulnerabilities | Varies by base image                | None found (as per current scans)                   |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- Docker Debug to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

### Debugging examples

Using Docker Debug:

```bash
docker debug mongodb-exporter
```

Using Image Mount feature:

```bash
docker run --rm -it --pid container:mongodb-exporter \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/mongodb-exporter:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Runtime variants** are designed to run your application in production. These images are intended to be used either
directly or as the FROM image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

**Build-time variants** typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

**Note:** The MongoDB Exporter DHI currently only provides runtime variants as the exporter is distributed as a
pre-built binary.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image.

### Migration notes

| Item               | Migration note                                                                                                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                   |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                   |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                  |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                      |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                          |
| Ports              | Non-dev hardened images run as a nonroot user by default. MongoDB Exporter's default port 9216 works without issues as it's above 1024.                                                     |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                 |

### Migration process

1. **Find hardened images for your app**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update deployment configuration**

   For MongoDB Exporter, you typically don't need a custom Dockerfile. Update your Docker Compose files, Kubernetes
   manifests, or Docker run commands to use the hardened image:

   ```bash
   # Before
   docker run -d -p 9216:9216 percona/mongodb_exporter:0.40 \
     --mongodb.uri=mongodb://localhost:27017

   # After
   docker run -d -p 9216:9216 dhi.io/mongodb-exporter:0.47.1-debian13 \
     --mongodb.uri=mongodb://localhost:27017
   ```

1. **Verify functionality**

   After migration, verify that:

   - The exporter connects to MongoDB successfully
   - Metrics are being exported correctly
   - Prometheus can scrape the metrics
   - No authentication issues exist

   ```bash
   # Test metrics endpoint
   curl http://localhost:9216/metrics | grep mongodb_up

   # Should return: mongodb_up 1
   ```

## Troubleshooting migration

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use Docker Debug to attach to these containers. Docker
Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that
only exists during the debugging session.

```bash
docker debug mongodb-exporter
```

#### Permissions

By default image variants intended for runtime, run as the nonroot user. This typically doesn't cause issues for MongoDB
Exporter as it only needs network access and doesn't require file system writes.

#### Privileged ports

MongoDB Exporter uses port 9216 by default, which is above 1024, so there are no privileged port issues. If you need to
customize the port, ensure you use a port above 1024:

#### No shell

By default, image variants intended for runtime don't contain a shell. For MongoDB Exporter, all configuration is done
via command-line flags or environment variables, so shell access is rarely needed. Use Docker Debug to troubleshoot
containers with no shell.

#### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your configuration if necessary.
