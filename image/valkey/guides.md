## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this Valkey image

This Docker Hardened Valkey image includes the complete Valkey toolkit in a single, security-hardened package:

- `valkey-server`: The main Valkey server
- `valkey-cli`: Valkey command-line interface
- `valkey-benchmark`: Performance testing tool
- `valkey-check-aof`: AOF file checker and repairer
- `valkey-check-rdb`: RDB file checker

For Redis compatibility, the image also includes symbolic links that allow you to use the traditional Redis command
names:

- `redis-server` -> `valkey-server`
- `redis-cli` -> `valkey-cli`
- `redis-benchmark` -> `valkey-benchmark`
- `redis-sentinel` -> `valkey-server`
- `redis-check-aof` -> `valkey-check-aof`
- `redis-check-rdb` -> `valkey-check-rdb`

### Run a Valkey container

Run the following command to run a Valkey container and output the help. Replace `<tag>` with the image variant you want
to run.

```console
$ docker run --rm dhi.io/valkey:<tag> valkey-server --help
```

## Common Valkey use cases

### Basic Valkey server

Start a Valkey server instance:

```console
$ docker run --name my-valkey -d dhi.io/valkey:<tag> valkey-server
```

Connect to the server using the `valkey-cli`:

```console
$ docker exec -it my-valkey valkey-cli ping
PONG
```

### Valkey with persistent storage

Run Valkey with data persistence using a Docker volume:

```console
$ docker run --name valkey-persistent -d \
  -v valkey-data:/data \
  dhi.io/valkey:<tag> sh -c "cd /data && valkey-server --appendonly yes"
```

This enables AOF (Append-Only File) persistence, which logs every write operation to ensure data durability. The data
will be stored in the Docker volume and persist across container restarts.

### Run Valkey with custom configuration using Docker Compose

Create a `custom-valkey.conf` file:

```conf
port 6380
maxmemory 128mb
maxmemory-policy volatile-lru
timeout 300
loglevel verbose
databases 8
```

Create a `compose.yml` file:

```yaml
services:
  valkey-custom:
    image: dhi.io/valkey:<tag>
    container_name: valkey-custom
    ports:
      - "6380:6380"
    volumes:
      - "./custom-valkey.conf:/tmp/valkey.conf:ro"
    command: valkey-server /tmp/valkey.conf
```

Run with Docker Compose:

```console
$ docker compose up -d
```

### Use Valkey in Kubernetes

To use the Valkey hardened image in Kubernetes, [set up authentication](https://docs.docker.com/dhi/how-to/k8s/) and
update your Kubernetes deployment. For example, in your `valkey.yaml` file, replace the image reference in the container
spec. In the following example, replace `<tag>` with your organization's namespace and the desired tag.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: valkey
  namespace: <kubernetes-namespace>
spec:
  template:
    spec:
      containers:
        - name: valkey
          image: dhi.io/valkey:<tag>
          ports:
            - containerPort: 6379
      imagePullSecrets:
        - name: <your-registry-secret>
```

Then apply the manifest to your Kubernetes cluster.

```console
$ kubectl apply -n <kubernetes-namespace> -f valkey.yaml
```

## Non-hardened images vs. Docker Hardened Images

### Key differences

| Feature            | Valkey non-hardened image                        | Valkey Docker Hardened Image                |
| ------------------ | ------------------------------------------------ | ------------------------------------------- |
| Base OS            | Debian and Alpine                                | Debian                                      |
| User context       | Runs as `root` (uid/gid 0)                       | Runs as `nonroot` user (uid/gid 65532)      |
| Shell access       | Full shell available                             | No shell or shell utilities                 |
| Package management | Package manager included                         | No package manager                          |
| Attack surface     | Larger due to root user and additional utilities | Minimal, only essential Valkey components   |
| Security posture   | Standard container security                      | Ships with SBOM and VEX metadata            |
| Debugging          | Traditional shell debugging and root access      | Use Docker Debug or image mount for tooling |

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

Docker Hardened Images come in different variants depending on their intended use. The Valkey image contains only the
runtime variant. Runtime variants are designed to run your application in production. These images are intended to be
used either directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

## Migrate to a Docker Hardened Image

Switching to the hardened Valkey image requires minimal changes for most use cases.

### Migration steps

1. Replace the image reference in your configuration file or command.

1. If using custom configuration files, update mount paths to writable locations for the nonroot user.

1. All your existing environment variables, port mappings, and volume mounts for data persistence remain the same.

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
