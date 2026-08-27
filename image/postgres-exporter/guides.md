## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Postgres Exporter instance

Run the following command and replace `<tag>` with the image variant you want to run.

```bash
# First, start a PostgreSQL instance
docker run -d \
  --name postgres-server \
  -e POSTGRES_PASSWORD=mysecretpassword \
  -p 5432:5432 \
  dhi.io/postgres:18

# Then start the postgres-exporter
docker run -d \
  --name postgres-exporter \
  -p 9187:9187 \
  -e DATA_SOURCE_NAME="postgresql://postgres:mysecretpassword@postgres-server:5432/postgres?sslmode=disable" \
  --link postgres-server \
  dhi.io/postgres-exporter:<tag>

# Verify it's working
curl http://localhost:9187/metrics

# Clean up after testing
docker rm -f postgres-server postgres-exporter
```

## Common Postgres Exporter use cases

### Custom metrics with queries.yaml

Create a custom queries configuration file:

```bash
# Create queries.yaml
cat > queries.yaml << 'EOF'
pg_replication:
  query: "SELECT CASE WHEN NOT pg_is_in_recovery() THEN 0 ELSE GREATEST (0, EXTRACT(EPOCH FROM (now() - pg_last_xact_replay_timestamp()))) END AS lag"
  master: true
  metrics:
    - lag:
        usage: "GAUGE"
        description: "Replication lag behind master in seconds"

pg_postmaster:
  query: "SELECT pg_postmaster_start_time as start_time_seconds from pg_postmaster_start_time()"
  master: true
  metrics:
    - start_time_seconds:
        usage: "GAUGE"
        description: "Time at which postmaster started"
EOF

# Run exporter with custom queries
docker run -d \
  --name postgres-exporter \
  -p 9187:9187 \
  -v $(pwd)/queries.yaml:/queries.yaml:ro \
  -e DATA_SOURCE_NAME="postgresql://postgres:mysecretpassword@postgres-server:5432/postgres?sslmode=disable" \
  -e PG_EXPORTER_EXTEND_QUERY_PATH="/queries.yaml" \
  --link postgres-server \
  dhi.io/postgres-exporter:<tag>

# Clean up after testing
docker rm -f postgres-exporter
rm queries.yaml
```

### TLS/SSL connection

Monitor PostgreSQL with TLS/SSL enabled:

```bash
# Start exporter with TLS connection
docker run -d \
  --name postgres-exporter-tls \
  -p 9187:9187 \
  -e DATA_SOURCE_NAME="postgresql://postgres:mysecretpassword@postgres-server:5432/postgres?sslmode=require" \
  --link postgres-server \
  dhi.io/postgres-exporter:<tag>

# For advanced TLS configurations with certificates
docker run -d \
  --name postgres-exporter-tls \
  -p 9187:9187 \
  -v /path/to/certs:/certs:ro \
  -e DATA_SOURCE_NAME="postgresql://postgres:mysecretpassword@postgres-server:5432/postgres?sslmode=verify-full&sslrootcert=/certs/ca.crt&sslcert=/certs/client.crt&sslkey=/certs/client.key" \
  --link postgres-server \
  dhi.io/postgres-exporter:<tag>

# Clean up after testing
docker rm -f postgres-exporter-tls
```

### Docker Compose deployment

Complete monitoring stack with PostgreSQL and PostgreSQL Exporter:

```yaml
services:
  postgres:
    image: dhi.io/postgres:18
    container_name: postgres-server
    environment:
      POSTGRES_PASSWORD: mysecretpassword
      POSTGRES_DB: mydb
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    restart: unless-stopped

  postgres-exporter:
    image: dhi.io/postgres-exporter:<tag>
    container_name: postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:mysecretpassword@postgres:5432/postgres?sslmode=disable"
    ports:
      - "9187:9187"
    depends_on:
      - postgres
    restart: unless-stopped

volumes:
  postgres-data:
```

### Integration with Prometheus

Configure Prometheus to scrape PostgreSQL Exporter metrics:

**First, create prometheus.yml:**

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']
```

**Then create docker-compose.yml:**

```yaml
services:
  postgres:
    image: dhi.io/postgres:18
    container_name: postgres-server
    environment:
      POSTGRES_PASSWORD: mysecretpassword
      POSTGRES_DB: mydb
    volumes:
      - postgres-data:/var/lib/postgresql/data

  postgres-exporter:
    image: dhi.io/postgres-exporter:<tag>
    container_name: postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:mysecretpassword@postgres:5432/postgres?sslmode=disable"
    depends_on:
      - postgres

  prometheus:
    image: dhi.io/prometheus:3
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prom_data:/var/prometheus
    depends_on:
      - postgres-exporter

volumes:
  postgres-data:
  prom_data:
```

### Kubernetes deployment

Deploy postgres-exporter in Kubernetes to monitor PostgreSQL instances:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-exporter-config
  namespace: monitoring
data:
  DATA_SOURCE_NAME: "postgresql://postgres:password@postgres-service:5432/postgres?sslmode=disable"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-exporter
  namespace: monitoring
  labels:
    app: postgres-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres-exporter
  template:
    metadata:
      labels:
        app: postgres-exporter
    spec:
      containers:
      - name: postgres-exporter
        image: dhi.io/postgres-exporter:<tag>
        ports:
        - containerPort: 9187
          name: metrics
        env:
        - name: DATA_SOURCE_NAME
          valueFrom:
            configMapKeyRef:
              name: postgres-exporter-config
              key: DATA_SOURCE_NAME
        livenessProbe:
          httpGet:
            path: /
            port: 9187
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 9187
          initialDelaySeconds: 5
          periodSeconds: 5
        resources:
          limits:
            cpu: 100m
            memory: 128Mi
          requests:
            cpu: 50m
            memory: 64Mi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres-exporter
  namespace: monitoring
  labels:
    app: postgres-exporter
spec:
  type: ClusterIP
  ports:
  - port: 9187
    targetPort: 9187
    name: metrics
  selector:
    app: postgres-exporter
```

### ServiceMonitor for Prometheus Operator

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: postgres-exporter
  namespace: monitoring
  labels:
    app: postgres-exporter
spec:
  selector:
    matchLabels:
      app: postgres-exporter
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Available image tags for postgres-exporter:**

| Variant Type          | Tag Examples                                     | Description                          |
| --------------------- | ------------------------------------------------ | ------------------------------------ |
| **Standard (Debian)** | `0.18.1`, `0.18`, `0`                            | Runtime variants for production use  |
|                       | `0.18.1-debian13`, `0.18-debian13`, `0-debian13` | Explicit Debian base specification   |
| **FIPS (Debian)**     | `0.18.1-fips`, `0.18-fips`, `0-fips`             | FIPS-validated cryptographic modules |
|                       | `0.18.1-debian13-fips`, `0.18-debian13-fips`     | FIPS with explicit Debian base       |

**Tag selection guidance:**

- Use `dhi.io/postgres-exporter:0.18.1` for standard production deployments
- Use `dhi.io/postgres-exporter:0.18.1-fips` for FIPS-compliant environments
- Use major version tags (like `:0`) for automatic minor updates (not recommended for production)

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

### FIPS variants

FIPS variants include `fips` in the variant name and tag. For PostgreSQL Exporter DHI, only runtime variants are
available. These variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard
for secure cryptographic operations.

**Runtime requirements specific to FIPS:**

- FIPS mode restricts cryptographic operations to FIPS-validated algorithms
- Usage of non-compliant operations (like MD5) will fail
- Larger image size due to FIPS-validated cryptographic libraries

**Steps to verify FIPS:**

```bash
# Check if FIPS variant is being used
docker inspect dhi.io/postgres-exporter:<tag> | grep fips

# Verify FIPS mode in running container (if applicable)
docker logs <container-name>
```

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                             |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                             |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                            |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                    |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. PostgreSQL Exporter default port 9187 works without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                           |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                           |

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

## Troubleshooting migration

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
