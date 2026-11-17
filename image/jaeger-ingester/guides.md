## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a jaeger-ingester instance

Run the following commands to verify the binary and explore available flags. Replace `<tag>` with the image variant you
want to run.

Print the binary version:

```bash
docker run --rm dhi.io/jaeger-ingester:<tag> version
```

Print all available flags:

```bash
docker run --rm dhi.io/jaeger-ingester:<tag> --help
```

## Common jaeger-ingester use cases

### Run as a Kafka ingester with the bundled configuration

The bundled configuration (`/etc/jaeger/config-kafka-ingester.yaml`) starts the `jaeger` binary in Kafka-ingester mode.
In this topology, a `jaeger-collector` (or any OpenTelemetry Collector with a Kafka exporter) receives spans from
instrumented services and publishes them to a Kafka topic. This ingester consumes that topic and writes spans to the
configured storage backend.

The bundled config uses an **in-memory** storage backend, which is non-durable and intended for demonstration only. All
spans are lost when the container stops. For durable storage, see the production section below.

The Kafka broker address is not env-templated in the bundled config — override it with `--set`:

```bash
docker run -d \
  --name jaeger-ingester \
  -p 16686:16686 \
  -p 14133:14133 \
  -p 8889:8889 \
  dhi.io/jaeger-ingester:<tag> \
  --config /etc/jaeger/config-kafka-ingester.yaml \
  --set "receivers::kafka::brokers=[kafka:9092]"
```

| Port  | Purpose                             |
| ----- | ----------------------------------- |
| 16686 | Jaeger UI and query API             |
| 14133 | HTTP health check (`healthcheckv2`) |
| 8889  | Prometheus metrics                  |

The Kafka receiver is an outbound consumer and does not expose an inbound port.

### Production: mount a custom config with durable storage

For production use, mount a configuration file that selects a durable backend such as Elasticsearch or OpenSearch. The
following example adapts the upstream Kafka-ingester and Elasticsearch samples into a single config. Keys are taken
verbatim from the upstream `cmd/jaeger/config-kafka-ingester.yaml` and `cmd/jaeger/config-elasticsearch.yaml` samples at
the v2.19.0 tag.

Create `my-config.yaml` on the host:

```yaml
# Jaeger v2 — Kafka ingester with Elasticsearch storage
service:
  extensions: [jaeger_storage, jaeger_query, healthcheckv2]
  pipelines:
    traces:
      receivers: [kafka]
      processors: [batch]
      exporters: [jaeger_storage_exporter]
  telemetry:
    resource:
      service.name: jaeger
    metrics:
      level: detailed
      readers:
        - pull:
            exporter:
              prometheus:
                host: 0.0.0.0
                port: 8889
    logs:
      level: info

extensions:
  healthcheckv2:
    use_v2: true
    http:
      endpoint: 0.0.0.0:14133

  jaeger_query:
    storage:
      traces: some_storage

  jaeger_storage:
    backends:
      some_storage:
        elasticsearch:
          server_urls:
            - http://elasticsearch:9200
          indices:
            index_prefix: "jaeger-main"
            spans:
              date_layout: "2006-01-02"
              rollover_frequency: "day"
              shards: 5
              replicas: 1
            services:
              date_layout: "2006-01-02"
              rollover_frequency: "day"
              shards: 5
              replicas: 1
            dependencies:
              date_layout: "2006-01-02"
              rollover_frequency: "day"
              shards: 5
              replicas: 1
            sampling:
              date_layout: "2006-01-02"
              rollover_frequency: "day"
              shards: 5
              replicas: 1

receivers:
  kafka:
    brokers:
      - kafka:9092
    traces:
      topics:
        - ${env:KAFKA_TOPIC:-jaeger-spans}
      encoding: ${env:KAFKA_ENCODING:-otlp_proto}
    initial_offset: earliest

processors:
  batch:

exporters:
  jaeger_storage_exporter:
    trace_storage: some_storage
```

Run with the custom config:

```bash
docker run -d \
  --name jaeger-ingester \
  -p 16686:16686 \
  -p 14133:14133 \
  -p 8889:8889 \
  -v ./my-config.yaml:/etc/jaeger/config.yaml \
  dhi.io/jaeger-ingester:<tag> \
  --config /etc/jaeger/config.yaml
```

For the full list of supported storage backends and their configuration keys, see the upstream configuration samples at
`https://github.com/jaegertracing/jaeger/tree/v<VERSION>/cmd/jaeger/`.

### Full pipeline with Docker Compose

The following Compose file wires together Kafka, Elasticsearch, a Jaeger collector (publishing spans to Kafka), and this
ingester (consuming from Kafka and writing to Elasticsearch).

```yaml
services:
  kafka:
    image: dhi/kafka:4
    environment:
      - KAFKA_BROKER_ID=1
      - KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092
      - KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1

  elasticsearch:
    image: elasticsearch:8.13.4
    environment:
      - discovery.type=single-node
      - xpack.security.enabled=false
    ports:
      - "9200:9200"

  jaeger-collector:
    # The collector role is the upstream unified jaeger binary; a hardened
    # dhi.io/jaeger image is not yet published, so this uses the upstream image.
    image: jaegertracing/jaeger:2.19.0
    depends_on:
      - kafka
    environment:
      - KAFKA_BROKER=kafka:9092
      - KAFKA_TOPIC=jaeger-spans
    command:
      - --config
      - /etc/jaeger/config-kafka-collector.yaml
      - --set
      - "exporters::kafka::brokers=[kafka:9092]"
    ports:
      - "4317:4317"
      - "4318:4318"

  jaeger-ingester:
    image: dhi.io/jaeger-ingester:<tag>
    depends_on:
      - kafka
      - elasticsearch
    environment:
      - KAFKA_TOPIC=jaeger-spans
    volumes:
      - ./my-config.yaml:/etc/jaeger/config.yaml
    command:
      - --config
      - /etc/jaeger/config.yaml
    ports:
      - "16686:16686"
      - "14133:14133"
      - "8889:8889"
```

`my-config.yaml` should be the production config shown in the previous section, with `kafka:9092` as the broker address
and `elasticsearch:9200` as the Elasticsearch URL.

### Advanced topics

For production deployments beyond the above examples, refer to the upstream v2 documentation:

- TLS encryption for the Kafka receiver: https://www.jaegertracing.io/docs/latest/storage/kafka/
- Tail-based sampling configuration: https://www.jaegertracing.io/docs/latest/sampling/
- Service Performance Monitoring (SPM): https://www.jaegertracing.io/docs/latest/architecture/spm/
- Storage backend configuration (Cassandra, OpenSearch): https://www.jaegertracing.io/docs/latest/storage/
- Migrating from Jaeger v1 to v2: https://www.jaegertracing.io/docs/latest/external-guides/migration/

## Non-hardened images vs. Docker Hardened Images

The DHI entrypoint is `/usr/local/bin/jaeger-ingester` (a symlink to `/usr/bin/jaeger`); the upstream v2 path
`/cmd/jaeger/jaeger-linux` is preserved as a symlink for compatibility with existing manifests. The image runs as the
DHI non-root user. In Jaeger v2 there is no standalone ingester binary — configuration is entirely file-driven via the
bundled `config-kafka-ingester.yaml` or a user-supplied config; v1-style environment variable flags such as
`SPAN_STORAGE_TYPE` and `KAFKA_CONSUMER_BROKERS` are not supported.

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
| Health check port  | The bundled Kafka-ingester config serves the `healthcheckv2` endpoint on port `14133`, not the `13133` used by the upstream all-in-one image. Update any health checks or probes that target `13133`.                                                                                                                        |
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
