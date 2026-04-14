## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

|                | Example                                    |
| -------------- | ------------------------------------------ |
| Public image   | `dhi.io/strimzi-kafka:<tag>`               |
| Mirrored image | `<your-namespace>/dhi-strimzi-kafka:<tag>` |

Before pulling images, authenticate to the registry:

```bash
docker login dhi.io
```

### What's included in this image

- Kafka broker and related binaries
- CIS benchmark compliance (runtime variant)
- FIPS 140, STIG, and CIS compliance (FIPS variant)

## Start a strimzi-kafka instance

Replace `<tag>` with the image variant you want to run:

```bash
docker run --rm dhi.io/strimzi-kafka:<tag> \
  /opt/kafka/bin/kafka-server-start.sh --version
```

## Common use cases

### Single Kafka broker setup

This image uses **KRaft mode** (ZooKeeper-free), which is the only supported mode in Kafka 4.x. KRaft requires the log
directory to be formatted with a cluster ID before the broker can start for the first time.

1. Create the `docker-compose.yml`:

   ```bash
   cat > docker-compose.yml << 'EOF'
   services:
     kafka:
       image: dhi.io/strimzi-kafka:<tag>
       container_name: kafka
       ports:
         - "9092:9092"
       environment:
         KAFKA_NODE_ID: 1
         KAFKA_PROCESS_ROLES: broker,controller
         KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
         KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
         KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
         KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:9093
         KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
       command:
         - /bin/bash
         - -c
         - |
           /opt/kafka/bin/kafka-storage.sh format \
             --config /opt/kafka/config/server.properties \
             --cluster-id $(cat /proc/sys/kernel/random/uuid | tr -d '-') && \
           /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
   EOF
   ```

Start the broker and verify it is running:

```bash
docker compose up -d
docker logs kafka
```

Look for the following lines to confirm a successful start:

```text
Transition from STARTING to STARTED
Kafka version: 4.2.0
Kafka Server started
Awaiting socket connections on 0.0.0.0:9092
```

Verify the broker API and create a test topic:

```bash
docker exec kafka /opt/kafka/bin/kafka-broker-api-versions.sh \
   --bootstrap-server localhost:9092

docker exec kafka /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server localhost:9092 \
  --create --topic test-topic \
  --partitions 1 --replication-factor 1
```

### Multiple broker configuration

Use Docker Compose to run a multi-broker KRaft cluster. Each broker requires a unique `KAFKA_NODE_ID`, listener port,
and shared `KAFKA_CONTROLLER_QUORUM_VOTERS` pointing to all three brokers. The structure for each service is identical
to the single broker setup above — duplicate the service block for `kafka-2` and `kafka-3`, updating `KAFKA_NODE_ID`,
the host port mapping, `KAFKA_ADVERTISED_LISTENERS`, and `KAFKA_CONTROLLER_QUORUM_VOTERS` accordingly:

```yaml
services:
  kafka-1:
    image: dhi.io/strimzi-kafka:<tag>
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      # ... same remaining env vars as single broker
    command: ["/bin/bash", "-c", "...same format+start command..."]

  kafka-2:
    image: dhi.io/strimzi-kafka:<tag>
    ports:
      - "9093:9092"
    environment:
      KAFKA_NODE_ID: 2
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      # ...
    command: ["/bin/bash", "-c", "..."]

  kafka-3:
    image: dhi.io/strimzi-kafka:<tag>
    ports:
      - "9094:9092"
    environment:
      KAFKA_NODE_ID: 3
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 3
      # ...
    command: ["/bin/bash", "-c", "..."]
```

Start and verify all brokers:

```bash
docker compose up -d
docker compose logs kafka-1 kafka-2 kafka-3
```

## Key Differences

| Feature         | DOI (`strimzi/kafka`)         | DHI (`dhi.io/strimzi-kafka`)                      |
| --------------- | ----------------------------- | ------------------------------------------------- |
| Base image      | CentOS 7                      | Debian 13 hardened base                           |
| Security        | Standard image, no CVE SLA    | Hardened build with security patches and metadata |
| Shell access    | Shell (`/bin/bash`) available | Shell available (runtime and dev variants)        |
| Package manager | `apt-get` available           | No package manager (runtime variants)             |
| User            | UID 1001                      | `kafka` user (UID 1001, nonroot)                  |
| FIPS compliance | No                            | Yes (FIPS variant, requires subscription)         |
| Architectures   | amd64                         | amd64, arm64                                      |
| Debugging       | Full shell and utilities      | Use Docker Debug for troubleshooting              |

## Migrate to a Docker Hardened Image

| Item                 | Migration note                                                                                                                                                                                                                 |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image           | Replace your base image in the Dockerfile with a Docker Hardened Image.                                                                                                                                                        |
| Package management   | Non-dev (runtime) images don't include package managers. Use package managers only in `dev`-tagged images.                                                                                                                     |
| Non-root user        | Runtime images run as the `kafka` user (UID 1001) by default. Ensure all required files and directories are accessible to this user.                                                                                           |
| Multi-stage builds   | Use `dev`-tagged images for build stages and non-dev images for the runtime stage.                                                                                                                                             |
| TLS certificates     | Docker Hardened Images include standard TLS certificates. No separate installation is needed.                                                                                                                                  |
| Ports                | Runtime images run as a nonroot user and cannot bind to privileged ports (below 1024) in Kubernetes or Docker Engine versions older than 20.10. Configure your application to listen on port 1025 or higher.                   |
| Entrypoint           | No entrypoint is set — pass the full binary path explicitly (e.g., `/opt/kafka/bin/kafka-server-start.sh`). Always supply an explicit `command` in Compose or Kubernetes manifests, otherwise the container exits immediately. |
| KRaft storage format | Kafka 4.x requires KRaft mode. Run `kafka-storage.sh format` before starting the broker for the first time.                                                                                                                    |
| No ZooKeeper         | Kafka 4.x does not support ZooKeeper. Remove any `zookeeper.connect` references from your config.                                                                                                                              |

## Troubleshoot migration

### General debugging

Runtime images don't include a shell or debugging tools. Use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers — it provides a shell,
common debugging tools, and lets you install additional tools in an ephemeral writable layer that exists only for the
duration of the session.

### Permissions

Runtime images run as the `kafka` user (UID 1001) by default. If your application can't access required files or
directories, copy them to a different path or update permissions so the `kafka` user can read them.

### Privileged ports

Runtime images run as a nonroot user and cannot bind to ports below 1024 in Kubernetes or Docker Engine versions older
than 20.10. Configure your application to use port 1025 or higher.

### Entrypoint

No entrypoint is set on this image. Run `docker inspect` to verify and always pass the full binary path explicitly in
your `command`.
