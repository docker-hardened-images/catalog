# How to use this Kafka Exporter image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

This guide provides practical examples for using the Kafka Exporter Hardened Image to send Kafka metrics to Prometheus.

## What's included in this Kafka Exporter image

This Docker Hardened Kafka Exporter image includes a Kafka exporter for Prometheus. For other metrics from Kafka, have a
look at the Docker Hardened JMX exporter image.

## Start a Kafka Exporter image

```bash
docker run -ti --rm -p 9308:9308 dhi.io/kafka-exporter:<tag> --kafka.server=kafka:9092
```

## Common use cases

### Run with Docker Compose

```bash
cat <<EOF > docker-compose.yml
services:
  kafka-exporter:
    image: dhi.io/kafka-exporter:<tag>
    command: ["--kafka.server=kafka:9092"]
    ports:
      - 9308:9308
EOF
```

### Run with Docker Compose

To test Kafka Exporter with a running Kafka broker, use this complete Docker Compose configuration:

```bash
cat <<EOF > docker-compose.yml
services:
  kafka:
    image: dhi.io/kafka:<tag>
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

  kafka-exporter:
    image: dhi.io/kafka-exporter:<tag>
    command: ["--kafka.server=kafka:9092"]
    ports:
      - "9308:9308"
    depends_on:
      - kafka
    restart: on-failure
EOF
```

Start the stack:

```console
$ docker compose up -d
```

Wait approximately 30 seconds for Kafka to initialize, then verify the metrics endpoint:

```console
$ curl http://localhost:9308/metrics | grep kafka_brokers
# HELP kafka_brokers Number of Brokers in the Kafka Cluster.
# TYPE kafka_brokers gauge
kafka_brokers 1
```

### Use Kafka Exporter in Kubernetes

To use the Kafka Exporter hardened image in Kubernetes, [set up authentication](https://docs.docker.com/dhi/how-to/k8s/)
and update your Kubernetes deployment.

```bash
cat <<EOF > kafka-exporter.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-exporter
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-exporter
  template:
    metadata:
      labels:
        app: kafka-exporter
    spec:
      containers:
        - name: kafka-exporter
          image: dhi.io/kafka-exporter:<tag>
          args:
            - --kafka.server=kafka:9092
          ports:
          - containerPort: 9308
            name: metrics
      imagePullSecrets:
        - name: <your-registry-secret>
EOF
```

Then apply the manifest to your Kubernetes cluster:

```console
$ kubectl apply -n default -f kafka-exporter.yaml
```

### Full Stack Kubernetes Deployment

To deploy both Kafka and Kafka Exporter in Kubernetes:

```bash
cat <<EOF > kafka.yaml
apiVersion: v1
kind: Service
metadata:
  name: kafka
  namespace: default
spec:
  ports:
    - port: 9092
      targetPort: 9092
  selector:
    app: kafka
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      containers:
        - name: kafka
          image: dhi.io/kafka:<tag>
          ports:
            - containerPort: 9092
            - containerPort: 9093
          env:
            - name: KAFKA_NODE_ID
              value: "1"
            - name: KAFKA_PROCESS_ROLES
              value: "broker,controller"
            - name: KAFKA_LISTENERS
              value: "PLAINTEXT://:9092,CONTROLLER://:9093"
            - name: KAFKA_ADVERTISED_LISTENERS
              value: "PLAINTEXT://kafka:9092"
            - name: KAFKA_CONTROLLER_LISTENER_NAMES
              value: "CONTROLLER"
            - name: KAFKA_CONTROLLER_QUORUM_VOTERS
              value: "1@localhost:9093"
            - name: KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR
              value: "1"
      imagePullSecrets:
        - name: <your-registry-secret>
EOF
```

```bash
cat <<EOF > kafka-exporter.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-exporter
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-exporter
  template:
    metadata:
      labels:
        app: kafka-exporter
    spec:
      containers:
        - name: kafka-exporter
          image: dhi.io/kafka-exporter:<tag>
          args:
            - --kafka.server=kafka:9092
          ports:
          - containerPort: 9308
            name: metrics
      imagePullSecrets:
        - name: <your-registry-secret>
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-exporter
  namespace: default
spec:
  ports:
    - port: 9308
      targetPort: 9308
  selector:
    app: kafka-exporter
EOF
```

Apply the manifests:

```console
$ kubectl apply -n default -f kafka.yaml
$ kubectl apply -n default -f kafka-exporter.yaml
```

Verify the deployment:

```console
$ kubectl get pods -n default
NAME                              READY   STATUS    RESTARTS   AGE
kafka-6959756cc4-bbkp9            1/1     Running   0          38s
kafka-exporter-6d4576bc86-p7f8h   1/1     Running   0          7s
```

Access the metrics:

```console
$ kubectl port-forward -n default deployment/kafka-exporter 9308:9308
$ curl http://localhost:9308/metrics | grep kafka_brokers
kafka_brokers 1
```

For examples of how to configure Kafka Exporter itself, see the
[Kafka Exporter documentation](https://github.com/danielqsj/kafka_exporter).

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened Kafka Exporter         | Docker Hardened Kafka Exporter                             |
| --------------- | ----------------------------------- | ---------------------------------------------------------- |
| Base image      | BusyBox container                   | Debian hardened base                                       |
| Security        | Standard image with basic utilities | Hardened build with security patches and security metadata |
| Shell access    | BusyBox shell (`/bin/sh`) available | No shell                                                   |
| Package manager | No package manager                  | No package manager                                         |
| User            | Runs as `nobody` (UID 65534)        | Runs as `nonroot` user (UID 65532)                         |
| Attack surface  | 400+ BusyBox utilities              | Only `kafka-exporter` binary, no additional utilities      |
| Debugging       | Full BusyBox shell and utilities    | Use Docker Debug or image mount for troubleshooting        |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```console
$ docker debug <container-name>
```

Or mount debugging tools with the image mount feature:

```console
$ docker run --rm -it --pid container:my-container \
  --mount=type=image,source=dhi.io/busybox:<tag>,destination=/dbg,ro \
  dhi.io/kafka-exporter:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

The Kafka Exporter image provides only runtime variants. Runtime variants are designed to run your application in
production. These images are intended to be used either directly or as the `FROM` image in the final stage of a
multi-stage build. These images typically:

- Run as a nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

### FIPS variants

FIPS variants include `fips` in the variant name and tag. These variants use cryptographic modules that have been
validated under FIPS 140, a U.S. government standard for secure cryptographic operations. Docker Hardened Kafka Exporter
images include FIPS-compliant variants for environments requiring Federal Information Processing Standards compliance.

#### Steps to verify FIPS:

```shell
# Compare image sizes (FIPS variants are larger due to FIPS crypto libraries)
$ docker images | grep kafka-exporter

# Verify FIPS compliance using image labels
$ docker inspect dhi.io/kafka-exporter:<tag>-fips \
  --format '{{index .Config.Labels "com.docker.dhi.compliance"}}'
fips
```

#### Runtime requirements specific to FIPS:

- FIPS mode enforces stricter cryptographic standards
- Use FIPS variants when connecting to Kafka clusters with FIPS-compliant TLS
- Required for deployments in US government or regulated environments
- Only FIPS-approved cryptographic algorithms are available for TLS connections

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                                                                                                                                                    |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                                                                                                                                                       |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

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

## Troubleshoot migration

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
