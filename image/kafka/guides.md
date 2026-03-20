## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What’s included in this Kafka image

This Docker Hardened Kafka image includes the complete Apache Kafka toolkit in a single, security-hardened package:

- `kafka-server-start.sh`: Main Kafka broker server
- `kafka-console-producer.sh`: Command-line producer for testing
- `kafka-console-consumer.sh`: Command-line consumer for testing
- `kafka-topics.sh`: Topic management utility
- `kafka-configs.sh`: Configuration management tool
- `kafka-consumer-groups.sh`: Consumer group management
- `kafka-log-dirs.sh`: Log directory information tool
- `kafka-metadata-shell.sh`: Metadata debugging utility
- `connect-standalone.sh`: Kafka Connect in standalone mode
- `connect-distributed.sh`: Kafka Connect in distributed mode

The image automatically handles KRaft mode initialization, including cluster ID generation and storage formatting,
making it easy to get started without complex configuration.

## Start a Kafka instance

Run the following command and replace `<tag>` with the image variant you want to run:

```bash
$ docker run --name some-kafka -d \
  -p 9092:9092 \
  dhi.io/kafka:<tag>
```

## Common Kafka use cases

### Why Docker Compose for Kafka?

While you can run Kafka with standalone Docker commands, we recommend using Docker Compose for several reasons:

- Kafka rarely runs alone: Production Kafka deployments include producers, consumers, and often multiple brokers
- Service dependencies: Docker Compose handles the startup order and ensures Kafka is ready before dependent services
  start
- Network isolation: Services can communicate using container names instead of IP addresses
- Easier configuration management: Environment variables and volumes are cleaner in YAML format
- Reproducible environments: Teams can share the same `docker-compose.yml` file for consistent development setups

### Complete Kafka application with Docker Compose

This example demonstrates a complete Kafka setup with topic creation, a producer, and a consumer using Docker Compose.

1. Create a `Dockerfile` for the Python services that need the Kafka client:

```dockerfile
FROM dhi.io/python:3.11-debian12-dev AS build
RUN pip install kafka-python

FROM dhi.io/python:3.11-debian12

COPY --from=build /opt/python/lib/ /opt/python/lib/
```

2. Create a `docker-compose.yml` file:

```yaml
services:
  kafka:
    image: dhi.io/kafka:<tag>
    container_name: kafka
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_PROCESS_ROLES: broker,controller
    volumes:
      - kafka-data:/opt/kafka/logs

  # Service to create topics
  init:
    build: .
    depends_on:
      - kafka
    command: ["python", "/init.py"]
    restart: on-failure
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
      KAFKA_TOPICS: test-topic,events-topic
    volumes:
      - ./init.py:/init.py

  # Consumer service
  consumer:
    build: .
    depends_on:
      init:
        condition: service_completed_successfully
    command: ["python", "/consumer.py"]
    restart: on-failure
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
      KAFKA_TOPIC: test-topic
    volumes:
      - ./consumer.py:/consumer.py

  # Producer service
  producer:
    build: .
    depends_on:
      init:
        condition: service_completed_successfully
    command: ["python", "/producer.py"]
    restart: always
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
      KAFKA_TOPIC: test-topic
    volumes:
      - ./producer.py:/producer.py

volumes:
  kafka-data:
```

3. Create the supporting Python scripts:

`init.py` creates topics:

```python
#!/usr/bin/env python
import os
from kafka import KafkaAdminClient
from kafka.admin import NewTopic
from kafka.errors import NoBrokersAvailable, TopicAlreadyExistsError

bootstrap_servers = os.environ['KAFKA_BOOTSTRAP_SERVERS']
topics = os.environ['KAFKA_TOPICS']

try:
    client = KafkaAdminClient(bootstrap_servers=bootstrap_servers)
except NoBrokersAvailable:
    print("Kafka not ready")
    exit(1)

new_topics = [NewTopic(topic, num_partitions=3, replication_factor=1)
              for topic in topics.split(",")]

try:
    client.create_topics(new_topics)
    print(f"Created topics: {topics}")
except TopicAlreadyExistsError:
    print("Topics already exist")
```

`consumer.py` consumes messages:

```python
#!/usr/bin/env python
import os
import sys
from kafka import KafkaConsumer

bootstrap_servers = os.environ['KAFKA_BOOTSTRAP_SERVERS']
topic = os.environ['KAFKA_TOPIC']

consumer = KafkaConsumer(topic, bootstrap_servers=bootstrap_servers)
print(f"Listening to topic: {topic}")

for msg in consumer:
    print(f"Received: {msg.value.decode()}")
    sys.stdout.flush()
```

`producer.py` produces messages:

```python
#!/usr/bin/env python
from datetime import datetime
import os
import time
from kafka import KafkaProducer

bootstrap_servers = os.environ['KAFKA_BOOTSTRAP_SERVERS']
topic = os.environ['KAFKA_TOPIC']

producer = KafkaProducer(bootstrap_servers=bootstrap_servers)

while True:
    message = f"Message at {datetime.now().isoformat()}"
    producer.send(topic, value=bytes(message, "utf-8"))
    print(f"Sent: {message}")
    producer.flush()
    time.sleep(5)  # Send a message every 5 seconds
```

4. Build and start the entire stack:

```bash
# Build the Python image with Kafka client
docker-compose build

# Start all services
docker-compose up -d
```

5. View logs to see messages being produced and consumed:

```bash
docker-compose logs -f consumer
docker-compose logs -f producer
```

### Simple Kafka broker for testing

For quick testing with the built-in console tools:

```yaml
version: '3.8'
services:
  kafka:
    image: dhi.io/kafka:<tag>
    container_name: kafka-test
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_PROCESS_ROLES: broker,controller
```

Test with console tools:

```bash
# Create a topic
docker exec kafka-test /opt/kafka/bin/kafka-topics.sh \
  --create --topic test \
  --bootstrap-server localhost:9092

# Start a console producer
docker exec -it kafka-test /opt/kafka/bin/kafka-console-producer.sh \
  --bootstrap-server localhost:9092 \
  --topic test

# In another terminal, start a console consumer
docker exec -it kafka-test /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic test \
  --from-beginning
```

### Multi-broker Kafka cluster

For production-like environments with multiple brokers:

```yaml
version: '3.8'
services:
  kafka-1:
    image: dhi.io/kafka:<tag>
    container_name: kafka-1
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-1:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
    volumes:
      - kafka-1-data:/opt/kafka/logs
    networks:
      - kafka-net

  kafka-2:
    image: dhi.io/kafka:<tag>
    container_name: kafka-2
    ports:
      - "9093:9092"
    environment:
      KAFKA_NODE_ID: 2
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-2:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
    volumes:
      - kafka-2-data:/opt/kafka/logs
    networks:
      - kafka-net

  kafka-3:
    image: dhi.io/kafka:<tag>
    container_name: kafka-3
    ports:
      - "9094:9092"
    environment:
      KAFKA_NODE_ID: 3
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka-3:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
    volumes:
      - kafka-3-data:/opt/kafka/logs
    networks:
      - kafka-net

networks:
  kafka-net:
    driver: bridge

volumes:
  kafka-1-data:
  kafka-2-data:
  kafka-3-data:
```

Create a replicated topic:

```bash
docker exec kafka-1 /opt/kafka/bin/kafka-topics.sh \
  --create --topic replicated-topic \
  --bootstrap-server kafka-1:9092 \
  --partitions 6 \
  --replication-factor 3
```

### Kafka with persistent storage

Ensure data persistence across container restarts:

```yaml
version: '3.8'
services:
  kafka:
    image: dhi.io/kafka:<tag>
    container_name: kafka-persistent
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@localhost:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_PROCESS_ROLES: broker,controller
    volumes:
      - kafka-logs:/opt/kafka/logs
      - kafka-kraft:/tmp/kraft-combined-logs
      - kafka-config:/opt/kafka/config

volumes:
  kafka-logs:
    driver: local
  kafka-kraft:
    driver: local
  kafka-config:
    driver: local
```

## Docker Official Images vs Docker Hardened Images

### Key differences

| Feature             | Docker Official Kafka               | Docker Hardened Kafka                        |
| ------------------- | ----------------------------------- | -------------------------------------------- |
| **Security**        | Standard base with common utilities | Minimal, hardened base with security patches |
| **Shell access**    | Full shell (bash/sh) available      | No shell in runtime variants                 |
| **Package manager** | apt/yum available                   | No package manager in runtime variants       |
| **User**            | May run as root                     | Runs as nonroot user                         |
| **Attack surface**  | Larger due to additional utilities  | Minimal, only essential components           |
| **Debugging**       | Traditional shell debugging         | Use Docker Debug for troubleshooting         |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

**For debugging**, use [Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) instead of shell
access:

```bash
docker debug my-kafka
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-kafka \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/kafka:<tag> /dbg/bin/sh
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

**FIPS variants** include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. For example, usage of MD5 fails in FIPS variants.

### Using FIPS variants

FIPS-enabled Kafka images are designed for environments requiring FIPS 140-3 compliance, such as government and
regulated industries.

**What's included:**

- **OpenSSL FIPS Provider**: FIPS 140-validated cryptographic operations at the OS level
- **BouncyCastle FIPS**: FIPS-validated Java cryptographic provider libraries
- **Enforced FIPS mode**: Pre-configured with `KAFKA_OPTS="-Dorg.bouncycastle.fips.approved_only=true"` to ensure only
  FIPS-approved algorithms are used

**Key characteristics:**

- Non-FIPS algorithms (like MD5) will cause runtime failures
- All TLS/SSL operations use FIPS-validated cryptographic modules
- BouncyCastle FIPS libraries are automatically included in `/opt/kafka/libs/`

**Example usage:**

```yaml
services:
  kafka:
    image: dhi.io/kafka:4.1-fips-debian13
    ports:
      - "9092:9092"
    environment:
      KAFKA_NODE_ID: 1
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_PROCESS_ROLES: broker,controller
    volumes:
      - kafka-data:/opt/kafka/logs

volumes:
  kafka-data:
```

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                        |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                             |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                           |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                            |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                            |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                    |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Kafka default ports (9092, 9093, 8083) work without issues. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                           |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                           |

The following steps outline the general migration process.

1. **Find hardened images for your app.** A hardened image may have several variants. Inspect the image tags and find
   the image variant that meets your needs.
1. **Update the base image in your Dockerfile.** Update the base image in your application's Dockerfile to the hardened
   image you found in the previous step. For framework images, this is typically going to be an image tagged as `dev`
   because it has the tools needed to install packages and dependencies.
1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.** To ensure that your final image is as
   minimal as possible, you should use a multi-stage build. All stages in your Dockerfile should use a hardened image.
   While intermediary stages will typically use images tagged as `dev`, your final runtime stage should use a non-dev
   image variant.
1. **Install additional packages** Docker Hardened Images contain minimal packages in order to reduce the potential
   attack surface. You may need to install additional packages in your Dockerfile. Inspect the image variants to
   identify which packages are already installed. Only images tagged as `dev` typically have package managers. You
   should use a multi-stage Dockerfile to install the packages. Install the packages in the build stage that uses a
   `dev` image. Then, if needed, copy any necessary artifacts to the runtime stage that uses a non-dev image. For
   Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to install
   packages.

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
