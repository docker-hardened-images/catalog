## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Start a RabbitMQ server instance

RabbitMQ stores data based on what it calls the "Node Name", which defaults to the hostname. When running a container in
Docker, you should specify `-h` or `--hostname` explicitly for each daemon so that you don't get a random hostname and
can keep track of our data. For example, run the following command and replace `<tag>` with the image variant you want
to run.

```console
$ docker run -d --hostname my-rabbit --name some-rabbit dhi.io/rabbitmq:<tag>
```

This starts a RabbitMQ server instance in a container named `some-rabbit` with the hostname `my-rabbit`.

## Common RabbitMQ use cases

### Configure using environment variables

The following example shows how to use environment variables to set the default user and password for RabbitMQ.

```console
$ docker run -d --hostname my-rabbit --name some-rabbit -e RABBITMQ_DEFAULT_USER=user -e RABBITMQ_DEFAULT_PASS=password dhi.io/rabbitmq:<tag>
```

This will create a new user `user` with password `password` and grant that user administrative privileges.

For a list of environment variables supported by RabbitMQ itself, see the official documentation for
[Environment Variables](https://www.rabbitmq.com/configure.html#supported-environment-variables.)⁠

### Enable management plugin

The management plugin provides a web-based UI for monitoring and administering your RabbitMQ server. You can use Docker
Compose with a volume mount:

```yaml
services:
  rabbitmq:
    image: dhi.io/rabbitmq:<tag>
    hostname: my-rabbit
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: user
      RABBITMQ_DEFAULT_PASS: password
    volumes:
      - ./enabled_plugins:/etc/rabbitmq/enabled_plugins:ro
```

Create an `enabled_plugins` file:

```console
$ echo '[rabbitmq_management].' > enabled_plugins
```

Run Docker Compose:

```console
$ docker compose up -d
```

Then go to `http://localhost:15672` in a browser and use `user` / `password` to log in.

### Configure using a config file

You can provide custom configuration using a bind-mounted config file:

```console
$ docker run -d --name some-rabbit -v /path/to/rabbitmq.conf:/etc/rabbitmq/rabbitmq.conf:ro dhi.io/rabbitmq:<tag>
```

Example `rabbitmq.conf` file:

```
default_user = myuser
default_pass = mypassword
vm_memory_high_watermark.relative = 0.4
```

For more details on configuring RabbitMQ, see the official documentation for
[Configuration File(s)](https://www.rabbitmq.com/docs/configure#configuration-files).

### Use RabbitMQ in Kubernetes

To use the RabbitMQ hardened image in Kubernetes, [set up authentication](https://docs.docker.com/dhi/how-to/k8s/) and
update your Kubernetes deployment. For example, in your `rabbitmq.yaml` file, replace the image reference in the
container spec. In the following example, replace `<tag>` with the desired tag.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rabbitmq
  namespace: <kubernetes-namespace>
spec:
  template:
    spec:
      containers:
        - name: rabbitmq
          image: dhi.io/rabbitmq:<tag>
          ports:
          - containerPort: 5672
      imagePullSecrets:
        - name: <your-registry-secret>
```

Then apply the manifest to your Kubernetes cluster.

```console
$ kubectl apply -n <kubernetes-namespace> -f rabbitmq.yaml
```

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature            | RabbitMQ non-hardened image           | RabbitMQ Docker Hardened Image (DHI)                |
| ------------------ | ------------------------------------- | --------------------------------------------------- |
| Base OS            | Ubuntu or Alpine Linux                | Debian                                              |
| Entry point        | `docker-entrypoint.sh`                | `rabbitmq-server` (direct)                          |
| User context       | Runs as `rabbitmq` (uid 999, gid 999) | Runs as `rabbitmq` user (uid/gid 65532)             |
| Shell access       | Full shell available                  | No shell or shell utilities                         |
| Package management | Package manager included              | No package manager                                  |
| Attack surface     | Larger due to additional utilities    | Minimal, only essential components                  |
| Security posture   | Standard security metadata            | Ships with SBOM and VEX metadata                    |
| Debugging          | Traditional shell debugging           | Use Docker Debug or image mount for troubleshooting |

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
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/<image-name>:<tag> /dbg/bin/sh
```

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

- Compat variants support more seamless usage of DHI as a drop-in replacement for upstream images, particularly for
  circumstances that the ultra-minimal runtime variant may not fully support. These images typically:

  - Run as the nonroot user
  - Improve compatibility with upstream helm charts
  - Include optional tools that are critical for certain use-cases

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

## Migrate to a Docker Hardened Image

Switching to the hardened RabbitMQ image requires minimal changes for basic use cases. However, be aware that the
hardened image uses `rabbitmq-server` as its entry point, while the standard image uses `docker-entrypoint.sh`, so
ensure that your commands and arguments are compatible.

### Migration steps

1. Replace the image reference in your Docker run command or Compose file.

1. All your existing environment variables, volume mounts, and network settings remain the same.

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
