## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `dhi.io/<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

To pull a temporalio-ui container, run the following command. Replace `<tag>` with the image variant you want to run.

```
$ docker pull dhi.io/temporalio-ui:<tag>
```

### Quick Start with Docker Compose

The admin tools image is designed to work alongside the Temporal server and can be used for management tasks.

To test locally use a `docker-compose.yml` file like the following, based on the temporal.io examples:
https://github.com/temporalio/docker-compose

```yaml
services:
  elasticsearch:
    container_name: temporal-elasticsearch
    environment:
      - cluster.routing.allocation.disk.threshold_enabled=true
      - cluster.routing.allocation.disk.watermark.low=512mb
      - cluster.routing.allocation.disk.watermark.high=256mb
      - cluster.routing.allocation.disk.watermark.flood_stage=128mb
      - discovery.type=single-node
      - ES_JAVA_OPTS=-Xms256m -Xmx256m
      - xpack.security.enabled=false
    image: elasticsearch:${ELASTICSEARCH_VERSION}
    networks:
      - temporal-network
    expose:
      - 9200
      - 9300
    ports:
      - 9200:9200
      - 9300:9300
    volumes:
      - /var/lib/elasticsearch/data
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:9200/_cluster/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5
  postgresql:
    container_name: temporal-postgresql
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_INITDB_ARGS: ${POSTGRES_INITDB_ARGS}
    image: ${POSTGRES_IMAGE}:${POSTGRES_VERSION}
    networks:
      - temporal-network
    expose:
      - 5432
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U temporal"]
      interval: 10s
      timeout: 5s
      retries: 5
  temporal:
    container_name: temporal
    depends_on:
      postgresql:
        condition: service_healthy
      elasticsearch:
        condition: service_healthy
    environment:
      - DB=postgres12
      - DB_PORT=5432
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PWD=${POSTGRES_PASSWORD}  # NOTE: env var ends in _PWD not _PASSWORD like on the server.
      - POSTGRES_SEEDS=${POSTGRES_SEEDS}
      - DYNAMIC_CONFIG_FILE_PATH=/etc/temporal/config/dynamicconfig/development-sql.yaml
      - ENABLE_ES=true
      - ES_SEEDS=elasticsearch
      - ES_VERSION=v7
      - SKIP_SCHEMA_SETUP=false # DHI does this independently to keep vulnerable tools off the server
      - TEMPORAL_ADDRESS=temporal:7233
      - TEMPORAL_CLI_ADDRESS=temporal:7233
    image: ${TEMPORAL_IMAGE}:${TEMPORAL_VERSION}
    networks:
      - temporal-network
    ports:
      - 7233:7233
    volumes:
      - ./dynamicconfig:/etc/temporal/config/dynamicconfig
    entrypoint: "/etc/temporal/entrypoint.sh autosetup"
    healthcheck:
      test: ["CMD-SHELL", "tctl cluster health | grep -q SERVING || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 60s
  temporal-admin-tools:
    container_name: temporal-admin-tools
    depends_on:
      temporal:
        condition: service_healthy
    environment:
      - TEMPORAL_ADDRESS=temporal:7233
      - TEMPORAL_CLI_ADDRESS=temporal:7233
    image: ${TEMPORAL_ADMIN_TOOLS_IMAGE}:${TEMPORAL_ADMIN_TOOLS_VERSION}
    networks:
      - temporal-network
    stdin_open: true
    tty: true
  temporal-ui:
    container_name: temporal-ui
    depends_on:
      temporal:
        condition: service_healthy
    environment:
      - TEMPORAL_ADDRESS=temporal:7233
      - TEMPORAL_CORS_ORIGINS=http://localhost:3000
    image: ${TEMPORAL_UI_IMAGE}:${TEMPORAL_UI_VERSION}
    networks:
      - temporal-network
    ports:
      - 8080:8080
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 5

networks:
  temporal-network:
    driver: bridge
    name: temporal-network

volumes:
  postgres_data:
```

Create a `dynamicconfig` directory and the required configuration file:

```bash
mkdir -p dynamicconfig
```

Create `dynamicconfig/development-sql.yaml` with the following content:

```yaml
limit.maxIDLength:
  - value: 255
    constraints: {}

system.forceSearchAttributesCacheRefreshOnRead:
  - value: true # Dev setup only. Please don't turn this on in production.
    constraints: {}
```

Use one of these env-files for DHI:

**For hardened images (env-dhi):**

```
TEMPORAL_IMAGE=dhi.io/temporalio-server
TEMPORAL_UI_IMAGE=dhi.io/temporalio-ui
TEMPORAL_ADMIN_TOOLS_IMAGE=dhi.io/temporalio-admin-tools
POSTGRES_IMAGE=postgres

TEMPORAL_VERSION=1.28
TEMPORAL_UI_VERSION=2.39.0
TEMPORAL_ADMIN_TOOLS_VERSION=1.28.1-tctl-1.18.2-cli-1.3.0
POSTGRES_VERSION=17

COMPOSE_PROJECT_NAME=temporal
CASSANDRA_VERSION=3.11.9
ELASTICSEARCH_VERSION=7.17.27
MYSQL_VERSION=8
POSTGRES_PASSWORD=hobbinnobbinsipsytipsyapplecartonrippledoven
POSTGRES_USER=temporal
POSTGRES_DEFAULT_PORT=5432
POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256
POSTGRES_SEEDS=postgresql
OPENSEARCH_VERSION=2.5.0
TEMPORAL_NETWORK=temporal-test_temporal-network
```

**For hardened images that are FIPS and STIG compliant (env-dhi-fips):**

```
TEMPORAL_IMAGE=dhi.io/temporalio-server
TEMPORAL_UI_IMAGE=dhi.io/temporalio-ui
TEMPORAL_ADMIN_TOOLS_IMAGE=dhi.io/temporalio-admin-tools
POSTGRES_IMAGE=postgres

TEMPORAL_VERSION=1.28-fips
TEMPORAL_UI_VERSION=2.39.0-fips
TEMPORAL_ADMIN_TOOLS_VERSION=1.28.1-tctl-1.18.2-cli-1.3.0-fips
POSTGRES_VERSION=17

COMPOSE_PROJECT_NAME=temporal
CASSANDRA_VERSION=3.11.9
ELASTICSEARCH_VERSION=7.17.27
MYSQL_VERSION=8
POSTGRES_PASSWORD=hobbinnobbinsipsytipsyapplecartonrippledoven
POSTGRES_USER=temporal
POSTGRES_DEFAULT_PORT=5432
POSTGRES_INITDB_ARGS=--auth-host=scram-sha-256
POSTGRES_SEEDS=postgresql
OPENSEARCH_VERSION=2.5.0
TEMPORAL_NETWORK=temporal-test_temporal-network
```

Start the services:

```bash
$ docker compose up
$ docker compose --env-file env-dhi up -d
```

Open the web server in a browser:

```bash
open http://localhost:8080
```

### Running Admin Commands

The examples below use the `docker-compose.yml` above and the `env-dhi` environment above. Adjusted versions can be used
with your k8s cluster.

Get a shell in the running admin tools container:

```bash
docker compose --env-file env-dhi exec -it temporal-admin-tools /bin/bash
```

```bash
# Check server health
$ docker compose --env-file env-dhi exec temporal-admin-tools \
  temporal operator cluster health

# List namespaces
$ docker compose --env-file env-dhi exec temporal-admin-tools\
  temporal operator namespace list

# Create a namespace
$ docker compose --env-file env-dhi exec temporal-admin-tools \
  temporal operator namespace create my-namespace
```

### Database Schema Management

Manage database schemas for Temporal:

```bash
# Create database schemas
$ docker compose --env-file env-dhi exec temporal-admin-tools \
  temporal-sql-tool --plugin postgres --ep your-postgres-host create-database

# Apply schema updates
$ docker compose --env-file env-dhi exec temporal-admin-tools \
  temporal-sql-tool --plugin postgres --ep your-postgres-host setup-schema
```

### Workflow and Activity Management

Debug and manage workflows:

```bash
# List running workflows in a namespace
$ docker compose --env-file env-dhi exec temporal-admin-tools \
  temporal workflow list --namespace my-namespace

# Show workflow details
$ docker compose --env-file env-dhi exec temporal-admin-tools \
  temporal workflow show \
  --workflow-id my-workflow-id \
  --namespace my-namespace

# Cancel a workflow
$ docker compose --env-file env-dhi exec temporal-admin-tools \
  temporal workflow cancel \
  --workflow-id my-workflow-id \
  --namespace my-namespace
```

### Using as Kubernetes Sidecar

Deploy as a sidecar container in Kubernetes:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: temporal-admin-tools
spec:
  replicas: 1
  selector:
    matchLabels:
      app: temporal-admin-tools
  template:
    metadata:
      labels:
        app: temporal-admin-tools
    spec:
      containers:
      - name: admin-tools
        image: dhi.io/temporalio-admin-tools:1.28
        env:
        - name: TEMPORAL_ADDRESS
          value: "temporal-frontend:7233"
        command: ["sleep", "infinity"]  # Keep container running
        resources:
          limits:
            memory: "256Mi"
            cpu: "200m"
          requests:
            memory: "128Mi"
            cpu: "100m"
```

Then execute commands:

```bash
$ kubectl exec -it deployment/temporal-admin-tools -- temporal operator cluster health
```

### Environment Variables

- `TEMPORAL_ADDRESS`: Temporal server address (default: `localhost:7233`)
- `TEMPORAL_NAMESPACE`: Default namespace for operations
- `POSTGRES_SEEDS`: PostgreSQL host(s) for database operations
- `POSTGRES_USER`: Database username
- `POSTGRES_PWD`: Database password

### Exposed Ports

The server has the following exposed ports:

- **7233**: Frontend gRPC (main client port)
- **7234**: Frontend HTTP
- **6933**: Frontend gRPC (alternative)
- **6934**: Frontend HTTP (alternative)
- **7235**: History membership
- **7239**: History metrics

### Available Tools

The image includes these administrative tools:

- `temporal`: Modern Temporal CLI for all operations
- `tctl`: Legacy Temporal CLI (for backwards compatibility)
- `temporal-sql-tool`: Database schema management
- `temporal-cassandra-tool`: Cassandra-specific database operations

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

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

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues,
configure your application to listen on port 1025 or higher inside the container, even if you map it to a lower port on
the host. For example, `docker run -p 80:8080 my-image` will work because the port inside the container is 8080, and
`docker run -p 80:81 my-image` won't work because the port inside the container is 81.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
