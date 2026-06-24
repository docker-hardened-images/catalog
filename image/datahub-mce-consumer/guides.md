## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/datahub-mce-consumer:<tag>`
- Mirrored image: `<your-namespace>/dhi-datahub-mce-consumer:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this datahub-mce-consumer image

This Docker Hardened DataHub MCE Consumer image packages the Metadata Change Event Consumer - the Kafka consumer
component of the [DataHub](https://datahub.com) open-source AI data catalog. DataHub is an enterprise-grade metadata
platform that enables discovery, governance, and observability across your entire data ecosystem, originally created at
LinkedIn and now maintained by the DataHub Project and Acryl Data.

- `datahub-mce-consumer`: Subscribes to the `MetadataChangeProposal_v1` Kafka topic produced by upstream metadata
  producers (the DataHub ingestion CLI, the DataHub actions framework, and other proposing services), validates each
  proposal, and applies it to DataHub's metadata storage layer via the GMS REST API. Successfully applied proposals flow
  downstream to `MetadataChangeLog_v1` (where the MAE Consumer picks them up to update search and graph indices); failed
  proposals are written back to `FailedMetadataChangeProposal_v1` for producers to retry. The service is a Spring Boot
  3.5.14 application built on OpenJDK 17 and is deployed as a fat JAR via `mce-consumer-job.jar`. This DHI image also
  bundles two optional Java agents - the OpenTelemetry javaagent and the JMX Prometheus javaagent - that are activated
  via environment variables at runtime.

The MCE Consumer can run standalone (this image's default) or be embedded inside `datahub-gms`. Standalone deployment
gives operators independent scaling and isolated failure domains for the metadata-write path.

### Run the datahub-mce-consumer container

The MCE Consumer only requires Kafka to come up before the JVM starts. It writes to DataHub GMS at request time over
HTTP, but does not gate startup on GMS reachability (failures retry from the Kafka offset). The `start.sh` entrypoint
uses `dockerize` to wait for the configured Kafka brokers (and optionally a Schema Registry) to become reachable before
launching the JVM, then exits non-zero if `dockerize`'s 240s timeout expires without all brokers responding.

To verify the bundled Java runtime version:

```bash
docker run --rm --entrypoint java dhi.io/datahub-mce-consumer:<tag> -version
```

To inspect the start script:

```bash
docker run --rm --entrypoint cat dhi.io/datahub-mce-consumer:<tag> \
  /datahub/datahub-mce-consumer/scripts/start.sh
```

### Deploy DataHub MCE Consumer with Docker Compose

The following example shows the MCE Consumer wired to Kafka, Zookeeper, and a Schema Registry. It is intended to
illustrate the required environment variable wiring - it is not a production-ready deployment. A real deployment also
requires DataHub GMS (the write target this consumer applies proposals against) and the rest of the DataHub stack.

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

  datahub-mce-consumer:
    image: dhi.io/datahub-mce-consumer:<tag>
    depends_on:
      - kafka
      - schema-registry
    environment:
      KAFKA_BOOTSTRAP_SERVER: kafka:9092
      KAFKA_SCHEMAREGISTRY_URL: http://schema-registry:8081
      DATAHUB_GMS_HOST: datahub-gms
      DATAHUB_GMS_PORT: 8080
      ENTITY_REGISTRY_CONFIG_PATH: /datahub/datahub-mce-consumer/resources/entity-registry.yml
      JAVA_OPTS: "-Xms512m -Xmx1g"
```

### Environment variables

Key environment variables for configuring the DataHub MCE Consumer:

| Variable                      | Description                                             | Default     | Required |
| ----------------------------- | ------------------------------------------------------- | ----------- | -------- |
| `KAFKA_BOOTSTRAP_SERVER`      | Kafka broker address (comma-separated for multi-broker) | -           | Yes      |
| `KAFKA_SCHEMAREGISTRY_URL`    | Schema Registry URL                                     | -           | Yes      |
| `DATAHUB_GMS_HOST`            | DataHub GMS hostname (write target)                     | -           | Yes      |
| `DATAHUB_GMS_PORT`            | DataHub GMS port                                        | `8080`      | Yes      |
| `ENTITY_REGISTRY_CONFIG_PATH` | Path to entity-registry.yml                             | (see below) | Yes      |
| `MCE_CONSUMER_ENABLED`        | Enable the standalone MCE consumer (default `true`)     | `true`      | No       |
| `SKIP_KAFKA_CHECK`            | Skip Kafka readiness wait in start.sh                   | `false`     | No       |
| `SKIP_SCHEMA_REGISTRY_CHECK`  | Skip Schema Registry readiness wait in start.sh         | `false`     | No       |
| `EXTRACT_JAR_ENABLED`         | Upstream tmpfs layertools optimization (not supported)  | (ignored)   | No       |
| `ENABLE_OTEL`                 | Enable OpenTelemetry javaagent                          | `false`     | No       |
| `ENABLE_PROMETHEUS`           | Enable JMX Prometheus javaagent on port 4318            | `false`     | No       |
| `JAVA_OPTS`                   | JVM flags (heap size, GC tuning, etc.)                  | `""`        | No       |

The bundled `entity-registry.yml` is at `/datahub/datahub-mce-consumer/resources/entity-registry.yml`. Set
`ENTITY_REGISTRY_CONFIG_PATH` to that path when not using an external registry file.

`SKIP_KAFKA_CHECK` and `SKIP_SCHEMA_REGISTRY_CHECK` default to `false` in this image. See
[Non-hardened images vs. Docker Hardened Images](#non-hardened-images-vs-docker-hardened-images) for how that differs
from upstream and how to restore skip-by-default behavior.

### Kafka topics

The MCE Consumer subscribes to:

- `MetadataChangeProposal_v1` - proposals from upstream producers (ingestion CLI, actions framework, etc.)

It writes failures back to:

- `FailedMetadataChangeProposal_v1` - rejected/error proposals that producers can retry

Successfully applied proposals appear on the downstream `MetadataChangeLog_v1` topic (consumed by the MAE Consumer) as a
side effect of the GMS write; the MCE Consumer does not produce there directly.

### Health check

The Spring Actuator health endpoint is available at port 9090. The runtime image includes `curl`, so use it for health
checks:

```bash
curl -fsS http://localhost:9090/actuator/health
```

In a Compose file:

```yaml
healthcheck:
  test: ["CMD", "curl", "-fsS", "http://localhost:9090/actuator/health"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 60s
```

### Deploy DataHub with the upstream Helm chart

For production Kubernetes deployments, use the upstream DataHub Helm chart, which deploys the full DataHub stack. To
substitute the Docker Hardened MCE Consumer image, override the image reference in your `values.yaml`:

```yaml
datahub-mce-consumer:
  image:
    repository: dhi.io/datahub-mce-consumer
    tag: <tag>
```

The upstream Helm chart is available at: https://artifacthub.io/packages/helm/datahub/datahub

### Enable observability agents

The two bundled Java agents are off by default and are activated at container start time via environment variables:

**OpenTelemetry tracing** (agent at `/datahub/datahub-mce-consumer/lib/opentelemetry-javaagent.jar`):

```yaml
environment:
  ENABLE_OTEL: "true"
  OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4318
```

**JMX Prometheus metrics** (agent at `/datahub/datahub-mce-consumer/lib/jmx_prometheus_javaagent.jar`). With
`ENABLE_PROMETHEUS=true` the agent opens a Prometheus scrape endpoint on port 4318. Operators must publish 4318
themselves; it is not in this image's `ports:` (the declared 9090/tcp is the Spring Boot actuator port):

```yaml
environment:
  ENABLE_PROMETHEUS: "true"
```

### FIPS variant

The `-fips` and `-fips-dev` variants configure the JVM to use BouncyCastle FIPS cryptographic modules (bc-fips,
bctls-fips, bcutil-fips, bc-rng-jent, bcpkix-fips). FIPS mode is activated via
`JDK_JAVA_OPTIONS=@/datahub/datahub-mce-consumer/scripts/datahub-fips.properties`, which is set automatically when you
use a `-fips` tag. No additional configuration is required to enable FIPS mode.

### Non-hardened images vs. Docker Hardened Images

This section documents intentional differences from upstream
[`acryldata/datahub-mce-consumer`](https://hub.docker.com/r/acryldata/datahub-mce-consumer) when migrating to the
hardened image. Kafka topic names, GMS write semantics, and the bundled DataHub `v1.5.0.7` application behavior are the
same; the items below are the ones operators must account for.

#### Differences from upstream

| Item                            | Upstream (`acryldata/datahub-mce-consumer`)                                           | Docker Hardened Image (`dhi.io/datahub-mce-consumer`)                                                                                                                  |
| :------------------------------ | :------------------------------------------------------------------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Runtime user                    | `datahub` (UID 100)                                                                   | `nonroot` (UID 65532)                                                                                                                                                  |
| Kafka readiness wait            | Skipped by default (`SKIP_KAFKA_CHECK` defaults to `true` in `start.sh`)              | Enabled by default (`SKIP_KAFKA_CHECK` defaults to `false`)                                                                                                            |
| Schema Registry readiness wait  | Waits when `KAFKA_SCHEMAREGISTRY_URL` is set unless `SKIP_SCHEMA_REGISTRY_CHECK=true` | Same condition, but `SKIP_SCHEMA_REGISTRY_CHECK` defaults to `false` (wait when the URL is set)                                                                        |
| GMS readiness at startup        | Does not wait for GMS (writes retry from Kafka offsets)                               | Same — not a behavioral change                                                                                                                                         |
| `EXTRACT_JAR_ENABLED`           | Optional Spring layertools extraction to tmpfs when set to `true`                     | Not supported; startup always runs `java -jar …/mce-consumer-job.jar`                                                                                                  |
| OpenTelemetry HTTP/2 frame size | `OTEL_EXPORTER_OTLP_HTTP_HTTP2_MAX_FRAME_SIZE=16777215`                               | `8388608` (8 MiB — halved to match other DataHub-family DHI images)                                                                                                    |
| Java agent paths                | `/opentelemetry-javaagent.jar` and `/jmx_prometheus_javaagent.jar` at the image root  | `/datahub/datahub-mce-consumer/lib/opentelemetry-javaagent.jar` and `…/jmx_prometheus_javaagent.jar` (activated via `ENABLE_OTEL` / `ENABLE_PROMETHEUS` in `start.sh`) |
| JVM option wiring               | `java $JAVA_OPTS $JMX_OPTS …` on the command line                                     | `JAVA_OPTS` and `JMX_OPTS` folded into `JAVA_TOOL_OPTIONS`; `JDK_JAVA_OPTIONS` is kept separate so FIPS `@argfile` expansion works                                     |
| Transitive dependencies         | Upstream-resolved versions (for example `spring-kafka@3.3.8`)                         | Gradle `resolutionStrategy` forces patched minimums where DHI remediates CVEs (for example `spring-kafka@3.3.16`, netty bumps)                                         |
| Runtime shell                   | Bash available                                                                        | No shell in the runtime variant (use `-dev` or [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/))                                                    |

#### Migration workarounds

- **Restore upstream skip-default startup checks** — set `SKIP_KAFKA_CHECK=true`. If you use Schema Registry and want
  upstream-style skip behavior, also set `SKIP_SCHEMA_REGISTRY_CHECK=true`.
- **`EXTRACT_JAR_ENABLED`** — leave unset or `false`. Upstream defaults this to `false`; the DHI runtime image does not
  implement the tmpfs layertools path (it requires a writable extraction directory the read-only nonroot runtime does
  not provide). Normal fat-JAR startup is supported.
- **Nonroot user** — mount ConfigMaps, Secrets, and volumes so UID/GID `65532` can read config and write any required
  paths. In Kubernetes, align `securityContext.runAsUser` / `fsGroup` with `65532` when replacing upstream pods that ran
  as `datahub`.
- **OpenTelemetry** — if you export very large OTLP payloads and hit HTTP/2 framing limits, reduce span or log payload
  size or tune the collector; the DHI default frame size is half of upstream's.
- **Custom scripts referencing agent JAR paths** — update paths to the `/datahub/datahub-mce-consumer/lib/` locations
  above; do not assume agents live at the image root.

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
