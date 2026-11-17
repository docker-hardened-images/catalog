## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a ClickHouse instance

Run the following command and replace `<tag>` with the image variant you want to run.

```
docker run --name my-clickhouse-server -d --ulimit nofile=262144:262144 dhi.io/clickhouse-server:<tag>
```

Verify the server is running:

```
docker exec my-clickhouse-server clickhouse-client --query "SELECT 'Hello from DHI ClickHouse!'"
```

## Common ClickHouse use cases

### Run ClickHouse with persistent storage

For production deployments, persist your data outside the container using volumes.

```
docker run -d \
  --name my-clickhouse-server \
  --ulimit nofile=262144:262144 \
  -v clickhouse-data:/var/lib/clickhouse \
  -v clickhouse-logs:/var/log/clickhouse-server \
  -p 8123:8123 \
  -p 9000:9000 \
  dhi.io/clickhouse-server:<tag>
```

### Run ClickHouse with custom configuration

Mount a custom configuration file to modify ClickHouse settings.

```
cat > custom-config.xml << EOF
<clickhouse>
    <logger>
        <level>information</level>
        <console>true</console>
    </logger>
    <listen_host>0.0.0.0</listen_host>
</clickhouse>
EOF

docker run -d \
  --name my-clickhouse-server \
  --ulimit nofile=262144:262144 \
  -v $(pwd)/custom-config.xml:/etc/clickhouse-server/config.d/custom.xml:ro \
  -p 8123:8123 \
  -p 9000:9000 \
  dhi.io/clickhouse-server:<tag>
```

### Run ClickHouse with network authentication

To enable HTTP and remote client access, set the `CLICKHOUSE_PASSWORD` environment variable. Without a password, network
access for the default user is disabled.

```
docker run -d \
  --name my-clickhouse-server \
  --ulimit nofile=262144:262144 \
  -e CLICKHOUSE_PASSWORD=mysecretpassword \
  -p 8123:8123 \
  -p 9000:9000 \
  dhi.io/clickhouse-server:<tag>
```

Test HTTP interface with authentication:

```
curl "http://localhost:8123/?query=SELECT%20version()&user=default&password=mysecretpassword"
```

### Connect with ClickHouse client

Use the ClickHouse client to connect to a running server instance.

```
docker run --rm -it --link my-clickhouse-server:clickhouse-server \
  dhi.io/clickhouse-server:<tag> \
  clickhouse-client --host clickhouse-server --password mysecretpassword
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official ClickHouse          | Docker Hardened ClickHouse                          |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | Shell available                                     |
| Package manager | apt available                       | No package manager                                  |
| User            | Runs as root by default             | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

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
docker debug <container-name>
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-clickhouse-server \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/clickhouse-server:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

The ClickHouse Docker Hardened Image is available as runtime variants only. There are no `dev` variants for this image.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item             | Migration note                                                                                                                                                                                                                                                                |
| ---------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image       | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                     |
| Non-root user    | By default, images run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                   |
| TLS certificates | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                            |
| Ports            | Hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. ClickHouse default ports 8123 and 9000 work without issues. |
| Entry point      | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                   |
| ulimits          | Always set `--ulimit nofile=262144:262144` for proper ClickHouse operation.                                                                                                                                                                                                   |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   ClickHouse images are available in multiple versions (25.3, 25.8, 25.11) with Debian 13 base.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step.

1. **Verify permissions**

   Since the image runs as nonroot user, ensure that data directories and mounted volumes are accessible to the nonroot
   user.

## Troubleshoot migration

### General debugging

The recommended method for debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/engine/reference/commandline/debug/) to attach to these containers. Docker Debug
provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only
exists during the debugging session.

### Permissions

By default image variants run as the nonroot user. Ensure that necessary files and directories are accessible to the
nonroot user. You may need to copy files to different directories or change permissions so your application running as
the nonroot user can access them.

### Privileged ports

Hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged
ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
