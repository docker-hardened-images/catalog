## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Loki instance

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
docker run -d --name loki -p 3100:3100 dhi.io/loki:<tag>
```

Verify that Loki is running:

```bash
# Check readiness (may take ~15 seconds)
curl http://localhost:3100/ready

# Check metrics endpoint
curl http://localhost:3100/metrics
```

## Common Loki use cases

### Log aggregation with Promtail

Loki works seamlessly with Promtail for collecting and shipping logs. Here's how to set up a basic log collection
pipeline using Docker Hardened Images:

```bash
mkdir -p promtail/config

cat > promtail/config/promtail.yml <<'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*.log
EOF

docker network create logging-net 2>/dev/null || true

docker run -d --name loki \
  --network logging-net \
  -p 3100:3100 \
  dhi.io/loki:<tag>

docker run -d --name promtail \
  --network logging-net \
  -p 9080:9080 \
  -v $PWD/promtail/config/promtail.yml:/etc/promtail/config.yml:ro \
  -v /var/log:/var/log:ro \
  dhi.io/promtail:<tag> \
  -config.file=/etc/promtail/config.yml

echo "Waiting for services to start..."
sleep 15

curl -s http://localhost:9080/metrics | grep promtail_targets_active_total

curl -s http://localhost:3100/loki/api/v1/labels | jq

curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="varlogs"}' \
  --data-urlencode 'limit=5' | jq
```

**Important notes:**

- Promtail Targets UI is available at: `http://localhost:9080/targets`
- Loki does not have a web UI. Accessing `http://localhost:3100` directly shows "404 page not found" - this is expected
  behavior.
- Both containers communicate via the `logging-net` Docker network

### Integration with Grafana

Loki integrates with Grafana for log visualization and querying:

```bash
docker network create logging-net 2>/dev/null || true

docker run -d \
  --name loki \
  --network logging-net \
  -p 3100:3100 \
  dhi.io/loki:<tag>

docker run -d \
  --name grafana \
  --network logging-net \
  -p 3000:3000 \
  -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
  dhi.io/grafana:<tag>

sleep 10

echo "Grafana is ready at http://localhost:3000"
echo "Default credentials - Username: admin, Password: admin"
```

Then configure Loki as a data source in Grafana:

1. Navigate to **Configuration** > **Data Sources**
1. Click **Add data source**
1. Select **Loki**
1. Set URL to `http://loki:3100`
1. Click **Save & Test**

### Custom configuration

Run Loki with a custom configuration file:

```bash
mkdir -p config

cat > config/loki-config.yaml <<'EOF'
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  tsdb_shipper:
    active_index_directory: /loki/tsdb-index
    cache_location: /loki/tsdb-cache
  filesystem:
    directory: /loki/chunks
EOF

docker run -d --name loki \
  -p 3100:3100 \
  -v $(pwd)/config/loki-config.yaml:/etc/loki/config.yaml:ro \
  -v loki-data:/loki \
  dhi.io/loki:<tag> \
  -config.file=/etc/loki/config.yaml

sleep 10

docker logs loki 2>&1 | head -20
```

### Query logs via API

Query logs directly using Loki's HTTP API:

```bash
curl -H "Content-Type: application/json" \
  -X POST "http://localhost:3100/loki/api/v1/push" \
  --data-raw '{
    "streams": [{
      "stream": { "job": "test", "environment": "dev" },
      "values": [ [ "'$(date +%s)000000000'", "Test log entry" ] ]
    }]
  }'

sleep 3

curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="test"}' \
  --data-urlencode 'limit=10' | jq

curl -s "http://localhost:3100/loki/api/v1/labels" | jq

curl -s "http://localhost:3100/loki/api/v1/label/job/values" | jq
```

### Access Prometheus metrics

Loki exposes Prometheus-style metrics on the `/metrics` endpoint:

```bash
# View all metrics
curl http://localhost:3100/metrics

# View specific metrics
curl -s http://localhost:3100/metrics | grep loki_ingester
```

**Sample metrics output:**

```
# HELP loki_build_info A metric with a constant '1' value labeled by version
# TYPE loki_build_info gauge
loki_build_info{branch="",goversion="go1.22.5",revision="",version="3.4.6"} 1

# HELP loki_ingester_chunks_created_total Total chunks created in the ingester
# TYPE loki_ingester_chunks_created_total counter
loki_ingester_chunks_created_total 0

# HELP process_resident_memory_bytes Resident memory size in bytes
# TYPE process_resident_memory_bytes gauge
process_resident_memory_bytes 1.12693248e+08
```

Key metrics include:

- Ingestion rates and volumes
- Query performance
- Resource usage (CPU, memory, file descriptors)
- Ring status and health
- Storage operations

## Non-hardened images vs Docker Hardened Images

### Key differences

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official Loki                | Docker Hardened Loki                                |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as user loki (UID 10001)       | Runs as nonroot user (UID 65532)                    |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug <image-name>
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it \
  --pid container:loki \
  --network container:loki \
  --cap-add SYS_PTRACE \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/loki:<tag>/dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Runtime variants** are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user (UID 65532)
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

**Build-time variants** typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

### FIPS variants

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations.

**FIPS Runtime Requirements:**

- FIPS mode enforces strict cryptographic operations
- MD5 and other non-compliant algorithms will fail
- Ensure your Loki configuration doesn't use deprecated hash algorithms
- TLS/SSL connections use FIPS 140-validated cryptographic modules

**Verify FIPS mode:**

Since DHI images don't include a shell, use Docker Debug to verify FIPS mode:

```bash
docker run -d --name loki-fips \
  -p 3100:3100 \
  dhi.io/loki:<tag>-fips

sleep 15

curl http://localhost:3100/ready

curl -s http://localhost:3100/metrics | grep loki_build_info
```

Push a test log to FIPS Loki:

```bash
curl -H "Content-Type: application/json" \
  -X POST "http://localhost:3100/loki/api/v1/push" \
  --data-raw '{
    "streams": [{
      "stream": { "job": "fips-test", "env": "production" },
      "values": [ [ "'$(date +%s)000000000'", "FIPS-compliant log entry" ] ]
    }]
  }'

sleep 3

curl -G -s "http://localhost:3100/loki/api/v1/query_range" \
  --data-urlencode 'query={job="fips-test"}' \
  --data-urlencode 'limit=5' | jq
```

Check FIPS-related logs:

```bash
docker logs loki-fips 2>&1 | grep -i fips
```

Use Docker Debug to verify FIPS mode (if Docker Debug is available):

```bash
docker debug loki-fips

# Inside the debug shell:
cat /proc/sys/crypto/fips_enabled
# Should output: 1

# You can also check OpenSSL FIPS mode
openssl version
# Should show FIPS-related information

# Exit debug shell
exit
```

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                       |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                            |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                            |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user (UID 65532). Note that official Loki images use UID 10001. Ensure that necessary files and directories are accessible to the nonroot user. |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                               |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                   |
| Ports              | Non-dev hardened images run as a nonroot user by default. Loki's default port 3100 is above 1024, so it works without issues.                                                                                        |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                          |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                          |

The following steps outline the general migration process:

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

By default image variants intended for runtime, run as the nonroot user (UID 65532). Ensure that necessary files and
directories are accessible to the nonroot user. You may need to copy files to different directories or change
permissions so your application running as the nonroot user can access them.

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
