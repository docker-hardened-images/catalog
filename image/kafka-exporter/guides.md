## How to use this Kafka Exporter image

This guide provides practical examples for using the Kafka Exporter Hardened Image to send Kafka metrics to Prometheus.

### What's included in this Kafka Exporter image

This Docker Hardened Kafka Exporter image includes a Kafka exporter for Prometheus. For other metrics from Kafka, have a
look at the Docker Hardened JMX exporter image.

### Start a Kafka Exporter image

```bash
docker run -ti --rm -p 9308:9308 <your-namespace>/dhi-kafka-exporter:<tag> --kafka.server=kafka:9092 [--kafka.server=kafka-2:9092 ...]
```

## Common use cases

### Run with Docker Compose

```yaml
services:
  kafka-exporter:
    image: <your-namespace>/dhi-kafka-exporter:<tag>
    command: ["--kafka.server=kafka:9092"] #", ... --kafka.server=kafka-2:9092 ..."
    ports:
      - 9308:9308
```

### Use Kafka Exporter in Kubernetes

To use the Kafka Exporter hardened image in Kubernetes, [set up authentication](https://docs.docker.com/dhi/how-to/k8s/)
and update your Kubernetes deployment. For example, in your `kafka-exporter.yaml` file, replace the image reference in
the container spec. In the following example replace `<your-namespace>` and `<tag>` with your organization's namespace
and the desired tag.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-exporter
  namespace: <kubernetes-namespace>
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
          image: <your-namespace>/dhi-kafka-exporter:<tag>
          args:
            - --kafka.server=kafka:9092
            - --kafka.server=kafka-2:9092
          ports:
          - containerPort: 9308
            name: metrics
      imagePullSecrets:
        - name: <your-registry-secret>
```

Then apply the manifest to your Kubernetes cluster.

```console
$ kubectl apply -n <kubernetes-namespace> -f kafka-exporter.yaml
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

```
docker debug <image-name>
```

or mount debugging tools with the image mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=<your-namespace>/dhi-busybox,destination=/dbg,ro \
  <your-namespace>/<image-name>:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. The Kafka Exporter image provides
only the runtime variant Runtime variants are designed to run your application in production. These images are intended
to be used either directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

## Migrate to a Docker Hardened Image

Switching to the hardened Kafka Exporter image does not require any special changes. You can use it as a drop-in
replacement for the standard Kafka Exporter image in your existing Docker deployments and configurations. The hardened
image uses the same port (9308) and accepts the same command-line arguments as the original.

### Migration steps

1. Update your image reference.

   Replace the image reference in your Docker run command or Compose file, for example:

   - From: `danielqsj/kafka-exporter:<tag>`
   - To: `<your-namespace>/dhi-kafka-exporter:<tag>`

1. All your existing command-line arguments, environment variables, port mappings, and network settings remain the same.

1. Test your migration and use the troubleshooting tips below if you encounter any issues.

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
