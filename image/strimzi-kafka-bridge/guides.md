## Prerequisites

- Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
  organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
  repository**, and then follow the on-screen instructions.
- To use the code snippets in this guide, replace `<your-namespace>` with your organization's namespace and `<tag>` with
  the image variant you want to run.

## What's included in this Strimzi Kafka Bridge image

This Docker Hardened Strimzi Kafka Bridge image includes:

- Strimzi Kafka Bridge runtime under /opt/strimzi (startup script: /opt/strimzi/bin/kafka_bridge_run.sh)
- The Kafka Bridge application artifacts and OpenAPI specification
- A Java runtime provided via the packaged Temurin artifact
- Default configuration files under /opt/strimzi/config (application.properties)

## Start a Strimzi Kafka Bridge image

The Kafka Bridge listens on port 8080 by default (inside the container). The bridge requires access to a running Kafka
cluster (bootstrap servers) and is configured via a config file.

The following is an example using Docker Compose.

### bridge.properties

```
# Kafka connection
kafka.bootstrap.servers=kafka:9092

# HTTP interface
http.host=0.0.0.0
http.port=8080
```

### docker-compose.yaml

```
services:
  kafka:
    image: dhi.io/strimzi-kafka:0.50-kafka-4.1.1
    container_name: kafka
    networks: [knet]
    ports:
      - "9092:9092"
    environment:
      LOG_DIR: "/tmp/logs"
    command:
      - sh
      - -c
      - |
        set -euo pipefail

        cat > /tmp/server.properties <<'EOF'
        process.roles=broker,controller
        node.id=1

        controller.listener.names=CONTROLLER
        listeners=PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
        advertised.listeners=PLAINTEXT://kafka:9092
        listener.security.protocol.map=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT

        controller.quorum.bootstrap.servers=kafka:9093

        log.dirs=/tmp/kraft-combined-logs
        num.partitions=1
        auto.create.topics.enable=true

        offsets.topic.replication.factor=1
        transaction.state.log.replication.factor=1
        transaction.state.log.min.isr=1
        EOF

        ./bin/kafka-storage.sh format \
          --standalone \
          -t "$$(./bin/kafka-storage.sh random-uuid)" \
          -c /tmp/server.properties

        exec ./bin/kafka-server-start.sh /tmp/server.properties

  kafka-bridge:
    image: dhi.io/strimzi-kafka-bridge:0.33.1
    container_name: kafka-bridge
    networks: [knet]
    depends_on:
      - kafka
    ports:
      - "8080:8080"
    volumes:
      - ./bridge.properties:/tmp/bridge.properties:ro
    command:
      - /opt/strimzi/bin/kafka_bridge_run.sh
      - --config-file=/tmp/bridge.properties

networks:
  knet:
    name: strimzi-kafka-net
```

To spin up the example run `docker compose up -d`.

### Environment variables

| Variable                       | Description                                                       | Default        | Required |
| ------------------------------ | ----------------------------------------------------------------- | -------------- | -------- |
| `STRIMZI_HOME`                 | Installation directory of the Strimzi Bridge inside the container | `/opt/strimzi` | No       |
| `STRIMZI_KAFKA_BRIDGE_VERSION` | Version string baked into the image                               | `0.33.1`       | No       |
| `JAVA_HOME`                    | Path to the Java runtime inside the container                     | set by image   | No       |

You can also configure the bridge by mounting a custom application.properties and/or starting the container with
additional arguments: `bin/kafka_bridge_run.sh --config-file /opt/strimzi/config/application.properties`.

## Common Strimzi Kafka Bridge use cases

- Bridge existing HTTP-based applications (web, mobile, legacy) to Kafka without using Kafka client libraries.
- Expose Kafka-producing endpoints for microservices that cannot include Kafka clients.
- Provide a lightweight HTTP-based integration layer in environments where full Kafka clients are undesirable.

Example: produce and consume messages using curl (assumes bridge available at http://localhost:8080):

1. Create a consumer:

```bash
curl -s -X POST -H "Content-Type: application/vnd.kafka.v2+json" \
  --data '{"name":"my-consumer","format":"json","auto.offset.reset":"earliest"}' \
  http://localhost:8080/consumers/my-group
```

2. Subscribe the consumer to a topic:

```bash
curl -s -X POST -H "Content-Type: application/vnd.kafka.v2+json" \
  --data '{"topics":["test-topic"]}' \
  http://localhost:8080/consumers/my-group/instances/my-consumer/subscription
```

3. Produce a message:

```bash
curl -s -X POST -H "Content-Type: application/vnd.kafka.json.v2+json" \
  --data '{"records":[{"value":{"msg":"hello"}}]}' \
  http://localhost:8080/topics/test-topic
```

4. Fetch messages for the consumer:

```bash
for i in {1..10}; do
  curl -s \
    -H "Accept: application/vnd.kafka.json.v2+json" \
    http://localhost:8080/consumers/my-group/instances/my-consumer/records
  sleep 1
done
```

### Configuration and persistence

- Configuration: the bridge is configured via the application.properties file under /opt/strimzi/config. Settings
  include bootstrap.servers, consumer/producer properties, HTTP port, and security (TLS/SASL) settings for Kafka
  connectivity.
- Persistence: The Kafka Bridge keeps consumer state (in-memory) inside the process — when the bridge restarts,
  in-memory consumers and subscriptions are lost. For production, prefer a single bridge instance with client affinity,
  or implement client-side reconnection logic.

### Security

- The Kafka Bridge HTTP endpoint does not provide TLS or authentication natively. For production deployments, put the
  bridge behind an API gateway or reverse proxy (TLS, auth) and use network policies to restrict access.
- Kafka connectivity supports TLS and SASL. Configure TLS/SASL for the bridge in application.properties to secure the
  connection to Kafka brokers.

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
  cryptographic operations. For example, usage of MD5 fails in FIPS variants. *End of FIPS section*

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
