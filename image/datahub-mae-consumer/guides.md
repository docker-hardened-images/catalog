## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/datahub-mae-consumer:<tag>`
- Mirrored image: `<your-namespace>/dhi-datahub-mae-consumer:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this datahub-mae-consumer image

This Docker Hardened DataHub MAE Consumer image packages the Metadata Audit Event Consumer - the Kafka consumer
component of the [DataHub](https://datahub.com) open-source AI data catalog. DataHub is an enterprise-grade metadata
platform that enables discovery, governance, and observability across your entire data ecosystem, originally created at
LinkedIn and now maintained by the DataHub Project and Acryl Data.

- `datahub-mae-consumer`: Subscribes to the `MetadataChangeLog_Versioned_v1` and `MetadataChangeLog_Timeseries_v1` Kafka
  topics produced by DataHub GMS and writes parsed events into the Elasticsearch (or OpenSearch) search index and
  optionally into Neo4j for graph-based lineage traversal. When `PE_CONSUMER_ENABLED=true`, it also processes the
  `PlatformEvent_v1` topic. The service is a Spring Boot application built on OpenJDK 17 and is deployed as a fat JAR
  via `mae-consumer-job.jar`. This DHI variant also bundles two optional Java agents - the OpenTelemetry javaagent and
  the JMX Prometheus javaagent - that are activated via environment variables at runtime.

The MAE Consumer runs alongside DataHub GMS, sharing the same Kafka, Elasticsearch or OpenSearch, and optional Neo4j
dependencies. Separating the consumer into its own process allows it to be scaled independently of GMS.

### Run the datahub-mae-consumer container

The MAE Consumer requires Kafka, Elasticsearch (or OpenSearch), and a running DataHub GMS instance before it starts. The
`start.sh` entrypoint uses `dockerize` to wait for Kafka, Elasticsearch, the Schema Registry, and optionally Neo4j to
become reachable before launching the JVM.

To verify the bundled Java runtime version:

```bash
docker run --rm --entrypoint java dhi.io/datahub-mae-consumer:<tag> -version
```

To inspect the start script:

```bash
docker run --rm --entrypoint cat dhi.io/datahub-mae-consumer:<tag> \
  /datahub/datahub-mae-consumer/scripts/start.sh
```

### Deploy DataHub MAE Consumer with Docker Compose

The following example shows the MAE Consumer wired to Kafka, Zookeeper, Elasticsearch, and a Schema Registry. It is
intended to illustrate the required environment variable wiring - it is not a production-ready deployment. A real
deployment also requires DataHub GMS and the other DataHub components.

```yaml
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.6.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181

  kafka:
    image: confluentinc/cp-kafka:7.6.0
    depends_on:
      - zookeeper
    environment:
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1

  schema-registry:
    image: confluentinc/cp-schema-registry:7.6.0
    depends_on:
      - kafka
    environment:
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: kafka:9092
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
    ports:
      - "8081:8081"

  elasticsearch:
    image: elasticsearch:8.13.0
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"

  datahub-mae-consumer:
    image: dhi.io/datahub-mae-consumer:<tag>
    depends_on:
      - kafka
      - schema-registry
      - elasticsearch
    environment:
      KAFKA_BOOTSTRAP_SERVER: kafka:9092
      KAFKA_SCHEMAREGISTRY_URL: http://schema-registry:8081
      ELASTICSEARCH_HOST: elasticsearch
      ELASTICSEARCH_PORT: 9200
      GRAPH_SERVICE_IMPL: elasticsearch
      DATAHUB_GMS_HOST: datahub-gms
      DATAHUB_GMS_PORT: 8080
      ENTITY_REGISTRY_CONFIG_PATH: /datahub/datahub-mae-consumer/resources/entity-registry.yml
      JAVA_OPTS: "-Xms512m -Xmx1g"
```

### Environment variables

Key environment variables for configuring the DataHub MAE Consumer:

| Variable                      | Description                                               | Default         | Required         |
| ----------------------------- | --------------------------------------------------------- | --------------- | ---------------- |
| `KAFKA_BOOTSTRAP_SERVER`      | Kafka broker address                                      | -               | Yes              |
| `KAFKA_SCHEMAREGISTRY_URL`    | Schema Registry URL                                       | -               | Yes              |
| `ELASTICSEARCH_HOST`          | Elasticsearch or OpenSearch hostname                      | -               | Yes              |
| `ELASTICSEARCH_PORT`          | Elasticsearch or OpenSearch port                          | `9200`          | Yes              |
| `ELASTICSEARCH_USE_SSL`       | Enable HTTPS for Elasticsearch                            | `false`         | No               |
| `ELASTICSEARCH_USERNAME`      | Elasticsearch username                                    | -               | No               |
| `ELASTICSEARCH_PASSWORD`      | Elasticsearch password                                    | -               | No               |
| `GRAPH_SERVICE_IMPL`          | Graph backend: `elasticsearch` or `neo4j`                 | `elasticsearch` | No               |
| `NEO4J_HOST`                  | Neo4j host URI (e.g. `http://neo4j:7474`)                 | -               | When using neo4j |
| `NEO4J_URI`                   | Neo4j Bolt URI (e.g. `bolt://neo4j:7687`)                 | -               | When using neo4j |
| `NEO4J_USERNAME`              | Neo4j username                                            | -               | When using neo4j |
| `NEO4J_PASSWORD`              | Neo4j password                                            | -               | When using neo4j |
| `DATAHUB_GMS_HOST`            | DataHub GMS hostname                                      | -               | Yes              |
| `DATAHUB_GMS_PORT`            | DataHub GMS port                                          | `8080`          | Yes              |
| `ENTITY_REGISTRY_CONFIG_PATH` | Path to entity-registry.yml                               | (see below)     | Yes              |
| `PE_CONSUMER_ENABLED`         | Enable PlatformEvent consumer on `PlatformEvent_v1` topic | `false`         | No               |
| `SKIP_KAFKA_CHECK`            | Skip Kafka readiness wait in start.sh                     | `false`         | No               |
| `SKIP_ELASTICSEARCH_CHECK`    | Skip Elasticsearch readiness wait in start.sh             | `false`         | No               |
| `SKIP_NEO4J_CHECK`            | Skip Neo4j readiness wait in start.sh                     | `false`         | No               |
| `SKIP_SCHEMA_REGISTRY_CHECK`  | Skip Schema Registry readiness wait in start.sh           | `false`         | No               |
| `ENABLE_OTEL`                 | Enable OpenTelemetry javaagent                            | `false`         | No               |
| `ENABLE_PROMETHEUS`           | Enable JMX Prometheus javaagent on port 4318              | `false`         | No               |
| `JAVA_OPTS`                   | JVM flags (heap size, GC tuning, etc.)                    | `""`            | No               |

The bundled `entity-registry.yml` is at `/datahub/datahub-mae-consumer/resources/entity-registry.yml`. Set
`ENTITY_REGISTRY_CONFIG_PATH` to that path when not using an external registry file.

### Kafka topics consumed

The MAE Consumer subscribes to the following topics by default:

- `MetadataChangeLog_Versioned_v1` - versioned metadata change events from GMS
- `MetadataChangeLog_Timeseries_v1` - time-series metadata change events from GMS
- `PlatformEvent_v1` - platform events (enabled when `PE_CONSUMER_ENABLED=true`)

### Health check

The Spring Actuator health endpoint is available at port 9091. The runtime image includes `curl` for health checks:

```bash
curl -fsS http://localhost:9091/actuator/health
```

In a Compose file, use the binary-native form:

```yaml
healthcheck:
  test: ["CMD", "curl", "-fsS", "http://localhost:9091/actuator/health"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 60s
```

### Deploy DataHub with the upstream Helm chart

For production Kubernetes deployments, use the upstream DataHub Helm chart, which deploys the full DataHub stack. To
substitute the Docker Hardened MAE Consumer image, override the image reference in your `values.yaml`:

```yaml
datahub-mae-consumer:
  image:
    repository: dhi.io/datahub-mae-consumer
    tag: <tag>
```

The upstream Helm chart is available at: https://artifacthub.io/packages/helm/datahub/datahub

### Enable observability agents

The two bundled Java agents are off by default and are activated at container start time via environment variables:

**OpenTelemetry tracing** (agent at `/datahub/datahub-mae-consumer/lib/opentelemetry-javaagent.jar`):

```yaml
environment:
  ENABLE_OTEL: "true"
  OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4318
```

**JMX Prometheus metrics** (agent at `/datahub/datahub-mae-consumer/lib/jmx_prometheus_javaagent.jar`). With
`ENABLE_PROMETHEUS=true` the agent opens a Prometheus scrape endpoint on port 4318. Operators must publish 4318
themselves; it is not in this image's `ports:` (the declared 9091/tcp is the Spring Actuator port):

```yaml
environment:
  ENABLE_PROMETHEUS: "true"
```

### FIPS variant

The `-fips` and `-fips-dev` variants configure the JVM to use BouncyCastle FIPS cryptographic modules (bc-fips,
bctls-fips, bcutil-fips, bc-rng-jent, bcpkix-fips). FIPS mode is activated via
`JDK_JAVA_OPTIONS=@/datahub/datahub-mae-consumer/scripts/datahub-fips.properties`, which is set automatically when you
use a `-fips` tag. No additional configuration is required to enable FIPS mode.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

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
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
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

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
