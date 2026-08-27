## Prerequisites

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

|                | Example                                       |
| -------------- | --------------------------------------------- |
| Public image   | `dhi.io/strimzi-operator:<tag>`               |
| Mirrored image | `<your-namespace>/dhi-strimzi-operator:<tag>` |

Before pulling images, authenticate to the registry:

```bash
docker login dhi.io
```

### What's included in this image

- Strimzi Cluster Operator binaries for managing Kafka on Kubernetes
- CIS benchmark compliance (runtime variant)
- FIPS 140, STIG, and CIS compliance (FIPS variant)

## Install Strimzi Operator using Helm

To install the Strimzi Operator using Helm with the Docker Hardened Image, follow these steps.

1. Create an image pull secret so Kubernetes nodes can authenticate to `dhi.io`:

   ```bash
   kubectl create secret docker-registry dhi-pull-secret \
     --docker-server=dhi.io \
     --docker-username=<your-docker-username> \
     --docker-password=<your-docker-pat> \
     --namespace kafka
   ```

1. Install the operator using the upstream Strimzi Helm chart, overriding the image with the DHI image:

   ```bash
   helm install strimzi-cluster-operator \
     --set defaultImageRegistry="" \
     --set image.repository=dhi.io/strimzi-operator \
     --set image.name="" \
     --set image.tag=<tag> \
     --set "image.imagePullSecrets[0].name=dhi-pull-secret" \
     oci://quay.io/strimzi-helm/strimzi-kafka-operator \
     --namespace kafka \
     --create-namespace
   ```

1. Verify the operator is running:

   ```bash
   kubectl rollout status deployment/strimzi-cluster-operator -n kafka
   kubectl get pods -n kafka
   ```

   Look for the following to confirm a successful rollout:

   ```text
   deployment "strimzi-cluster-operator" successfully rolled out
   NAME                                       READY   STATUS    RESTARTS   AGE
   strimzi-cluster-operator-<id>              1/1     Running   0          ...
   ```

## Start a strimzi-operator instance

```bash
docker run --rm dhi.io/strimzi-operator:<tag> \
  /opt/strimzi/bin/cluster_operator_run.sh --version
```

## Common use cases

### Setup a Kafka Cluster

Use Docker Compose to run the Strimzi Operator alongside a Kafka broker.

The operator has no default entrypoint — you must pass the run script explicitly via `command`. You must also provide
`STRIMZI_KAFKA_IMAGES`, `STRIMZI_KAFKA_CONNECT_IMAGES`, and `STRIMZI_KAFKA_MIRROR_MAKER_2_IMAGES` mappings for all Kafka
versions supported by the operator, otherwise it will fail to start.

1. Create the `docker-compose.yml`:

   ```yaml
   services:
     strimzi-operator:
       image: dhi.io/strimzi-operator:<tag>
       container_name: strimzi-operator
       command: /opt/strimzi/bin/cluster_operator_run.sh
       environment:
         STRIMZI_NAMESPACE: default
         STRIMZI_FULL_RECONCILIATION_INTERVAL_MS: 120000
         STRIMZI_LOG_LEVEL: INFO
         STRIMZI_KAFKA_IMAGES: "4.1.0=dhi.io/strimzi-kafka:<tag> 4.1.1=dhi.io/strimzi-kafka:<tag> 4.2.0=dhi.io/strimzi-kafka:<tag>"
         STRIMZI_KAFKA_CONNECT_IMAGES: "4.1.0=dhi.io/strimzi-kafka:<tag> 4.1.1=dhi.io/strimzi-kafka:<tag> 4.2.0=dhi.io/strimzi-kafka:<tag>"
         STRIMZI_KAFKA_MIRROR_MAKER_2_IMAGES: "4.1.0=dhi.io/strimzi-kafka:<tag> 4.1.1=dhi.io/strimzi-kafka:<tag> 4.2.0=dhi.io/strimzi-kafka:<tag>"

     kafka:
       image: dhi.io/strimzi-kafka:<tag>
       container_name: kafka
       ports:
         - "9092:9092"
       environment:
         KAFKA_NODE_ID: 1
         KAFKA_PROCESS_ROLES: broker,controller
         KAFKA_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
         KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
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
       depends_on:
         - strimzi-operator
   ```

1. Start the services and verify the operator is running:

   ```bash
   docker compose up -d
   docker compose logs strimzi-operator | grep "Health and metrics"
   ```

   Look for the following line to confirm the operator started successfully:

   ```text
   Health and metrics server is ready on port 8080
   ```

1. Create a test topic, produce a message, and consume it:

   ```bash
   docker exec kafka /opt/kafka/bin/kafka-topics.sh \
     --bootstrap-server localhost:9092 \
     --create --topic my-topic \
     --partitions 3 --replication-factor 1

   echo "Hello from DHI strimzi-kafka" | docker exec -i kafka \
     /opt/kafka/bin/kafka-console-producer.sh \
     --bootstrap-server localhost:9092 \
     --topic my-topic

   docker exec kafka /opt/kafka/bin/kafka-console-consumer.sh \
     --bootstrap-server localhost:9092 \
     --topic my-topic \
     --from-beginning \
     --max-messages 1
   ```

## Docker Official Image vs Docker Hardened Image

| Feature             | DOI (`quay.io/strimzi/operator`)   | DHI (`dhi.io/strimzi-operator`)         |
| ------------------- | ---------------------------------- | --------------------------------------- |
| Base OS             | UBI 9 Minimal (Red Hat)            | Debian 13                               |
| User                | `1001` (`strimzi`)                 | `nonroot`                               |
| Shell               | Yes (`bash`)                       | Yes (`bash`)                            |
| Package manager     | Yes (`microdnf`)                   | No                                      |
| Entrypoint          | `/usr/bin/tini` (via init process) | Unset (must pass `command` explicitly)  |
| Zero CVE commitment | No                                 | Yes                                     |
| FIPS variant        | No                                 | Yes (FIPS + STIG + CIS)                 |
| Compliance labels   | None                               | CIS (runtime), FIPS + STIG + CIS (fips) |

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the `nonroot` user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

The Strimzi Operator Docker Hardened Image is available as a runtime variant, a `dev` variant, and a `fips` variant. The
`fips` variant includes FIPS 140, STIG, and CIS compliance and is intended for use in regulated environments.

To view the image variants and get more information about them, select the **Images** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

| Item               | Migration note                                                                                                                                                                                                                     |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base image in the Dockerfile with a Docker Hardened Image.                                                                                                                                                            |
| Package management | Non-dev (runtime) images don't include package managers. Use package managers only in `dev`-tagged images.                                                                                                                         |
| Non-root user      | Runtime images run as the `strimzi` user (UID 1001) by default. Ensure all required files and directories are accessible to this user.                                                                                             |
| Multi-stage builds | Use `dev`-tagged images for build stages and non-dev images for the runtime stage.                                                                                                                                                 |
| TLS certificates   | Docker Hardened Images include standard TLS certificates. No separate installation is needed.                                                                                                                                      |
| Ports              | Runtime images run as a nonroot user and cannot bind to privileged ports (below 1024) in Kubernetes or Docker Engine versions older than 20.10. Configure your application to listen on port 1025 or higher.                       |
| Entrypoint         | No entrypoint is set — pass the full binary path explicitly (e.g., `/opt/strimzi/bin/cluster_operator_run.sh`). Always supply an explicit `command` in Compose or Kubernetes manifests, otherwise the container exits immediately. |

## Troubleshoot migration

### General debugging

Runtime images don't include a shell or debugging tools. Use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers — it provides a shell,
common debugging tools, and lets you install additional tools in an ephemeral writable layer that exists only for the
duration of the session.

### Permissions

Runtime images run as the `strimzi` user (UID 1001) by default. If the operator can't access required files or
directories, copy them to a different path or update permissions so the `strimzi` user can read them.

### Privileged ports

Runtime images run as a nonroot user and cannot bind to ports below 1024 in Kubernetes or Docker Engine versions older
than 20.10. Configure your application to use port 1025 or higher.

### Entrypoint

No entrypoint is set on this image. Run `docker inspect` to verify and always pass the full binary path explicitly in
your `command`.
