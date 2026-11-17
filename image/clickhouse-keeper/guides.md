## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a ClickHouse Keeper instance

Create the configuration file:

```
cat > keeper-config.xml << 'EOF'
<clickhouse>
    <logger>
        <level>information</level>
        <console>true</console>
    </logger>

    <listen_host>0.0.0.0</listen_host>

    <keeper_server>
        <tcp_port>2181</tcp_port>
        <server_id>1</server_id>
        <log_storage_path>/var/lib/clickhouse-keeper/coordination/log</log_storage_path>
        <snapshot_storage_path>/var/lib/clickhouse-keeper/coordination/snapshots</snapshot_storage_path>

        <four_letter_word_white_list>*</four_letter_word_white_list>

        <coordination_settings>
            <operation_timeout_ms>10000</operation_timeout_ms>
            <session_timeout_ms>30000</session_timeout_ms>
            <raft_logs_level>information</raft_logs_level>
        </coordination_settings>

        <raft_configuration>
            <server>
                <id>1</id>
                <hostname>localhost</hostname>
                <port>44444</port>
            </server>
        </raft_configuration>
    </keeper_server>
</clickhouse>
EOF
```

Start Keeper, mounting the config and a named volume for persistent coordination data. Replace `<tag>` with the image
variant you want to run.

```
docker run -d \
  --name my-clickhouse-keeper \
  -v $(pwd)/keeper-config.xml:/etc/clickhouse-keeper/keeper_config.xml:ro \
  -v keeper-data:/var/lib/clickhouse-keeper \
  -p 2181:2181 \
  -p 9181:9181 \
  -p 10181:10181 \
  -p 44444:44444 \
  dhi.io/clickhouse-keeper:<tag> \
  --config-file=/etc/clickhouse-keeper/keeper_config.xml
```

## Verify and monitor the instance

```
echo ruok | nc localhost 2181
```

A healthy instance responds with `imok`.

Use the `mntr` four-letter-word command to get detailed cluster health metrics:

```
echo mntr | nc localhost 2181
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official ClickHouse Keeper   | Docker Hardened ClickHouse Keeper                   |
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
docker run --rm -it --pid container:my-clickhouse-keeper \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/clickhouse-keeper:<tag> /dbg/bin/sh
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

The ClickHouse Keeper Docker Hardened Image is available as runtime variants only. There are no `dev` variants for this
image.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item             | Migration note                                                                                                                                                                                                                                                                           |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image       | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                |
| Non-root user    | By default, images run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                              |
| TLS certificates | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                       |
| Ports            | Hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Keeper default ports 2181, 9181, 10181, and 44444 work without issues. |
| Entry point      | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                              |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   ClickHouse Keeper images are available in multiple versions with Debian 13 base.

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
