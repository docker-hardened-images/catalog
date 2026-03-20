## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this Fluentd image

This Docker Hardened Fluentd image includes the complete Fluentd data collection platform in a single, security-hardened
package:

- **Fluentd daemon**: The main log collection and forwarding engine
- **Ruby runtime**: Optimized Ruby environment for Fluentd operations
- **Built-in plugins**: Core input, output, and filter plugins for common use cases
- **Configuration support**: Full support for Fluentd configuration files with flexible mounting options
- **Plugin system**: Architecture for installing additional plugins in development variants during build stages
- **TLS certificates**: Pre-installed CA certificates for secure connections

Unlike some other DHI images where runtime variants contain only the main binary, the Fluentd runtime image includes
essential plugins and Ruby gems needed for basic log processing operations. This design decision delivers operational
flexibility while maintaining security:

- Log routing and transformation require various plugins in production
- Configuration parsing needs Ruby runtime support
- Common integrations (file, HTTP, syslog) are included by default
- This bundling provides a complete logging toolkit in one security-hardened package

This approach aligns with real-world production use cases where Fluentd operations require more than just the daemon
binary.

## Start a Fluentd instance

Run the following command to start a Fluentd container. Replace `<path-to-your-configuration-file>` with the path to the
folder containing your `fluent.conf` file:

```bash
$ docker run --rm --name my-fluentd -p 9880:9880 \
  -v <path-to-your-configuration-file>:/fluent \
  dhi.io/fluentd:<tag> -c /fluent/fluent.conf
```

## Common Fluentd use cases

### Basic log forwarding with HTTP input

Create a simple configuration to receive logs via HTTP and output to stdout:

Create `fluent.conf`:

```conf
<source>
  @type http
  port 9880
  bind 0.0.0.0
</source>

<match **>
  @type stdout
</match>
```

Run Fluentd with the configuration:

```bash
docker run --name fluentd-http -p 9880:9880 \
  -v $(pwd):/fluent \
  dhi.io/fluentd:<tag> -c /fluent/fluent.conf
```

Send a test log:

```bash
curl -X POST -d 'json={"message":"hello world"}' http://localhost:9880/test.log
```

### File-based log collection

Collect logs from files and forward them to a remote destination:

Create `fluent.conf`:

```conf
<source>
  @type tail
  path /var/log/app/*.log
  pos_file /tmp/app.log.pos
  tag app.logs
  <parse>
    @type json
  </parse>
</source>

<match app.**>
  @type forward
  <server>
    host log-server.example.com
    port 24224
  </server>
</match>
```

Run with log file mounts:

```bash
docker run --name fluentd-tail -d \
  -v /var/log/app:/var/log/app:ro \
  -v $(pwd):/fluent \
  dhi.io/fluentd:<tag> -c /fluent/fluent-file.conf
```

### Kubernetes DaemonSet log collection

Deploy Fluentd as a DaemonSet to collect container logs:

Create `fluent.conf`:

```conf
<source>
  @type tail
  path /var/log/containers/*.log
  pos_file /tmp/fluentd-containers.log.pos
  tag kubernetes.*
  <parse>
    @type json
    time_format %Y-%m-%dT%H:%M:%S.%NZ
  </parse>
</source>

<filter kubernetes.**>
  @type kubernetes_metadata
</filter>

<match **>
  @type elasticsearch
  host elasticsearch.logging.svc.cluster.local
  port 9200
  index_name fluentd-k8s
</match>
```

### Add Fluentd plugins

To add Fluentd plugins, you need to create an image based on the development variant. Here's an example to add the
`fluent-plugin-s3`:

```dockerfile
# Build stage - use dev variant for plugin installation
FROM dhi.io/fluentd:<tag>-dev AS builder

RUN fluent-gem install fluent-plugin-s3 fluent-plugin-elasticsearch

# Runtime stage - copy plugins to runtime image
FROM dhi.io/fluentd:<tag>

COPY --from=builder /usr/local/bundle /usr/local/bundle
```

Build and use the custom image:

```bash
docker build -t my-fluentd-with-plugins .
docker run --name custom-fluentd -p 9880:9880 \
  -v $(pwd):/fluent \
  my-fluentd-with-plugins -c /fluent/fluent.conf
```

## Docker Official Images vs Docker Hardened Images

### Key differences

| Feature             | Docker Official Fluentd             | Docker Hardened Fluentd                             |
| ------------------- | ----------------------------------- | --------------------------------------------------- |
| Security            | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access        | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager     | apt/apk available                   | No package manager in runtime variants              |
| User                | Runs as root by default             | Runs as nonroot user for enhanced security          |
| Attack surface      | Larger due to additional utilities  | Minimal, only essential components                  |
| Plugin installation | Direct gem install in runtime       | Multi-stage build required for plugins              |
| Debugging           | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |
| Base OS             | Various Alpine/Debian versions      | Hardened Debian 13 base                             |

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

```bash
docker debug my-fluentd
```

or mount debugging tools with the Image Mount feature:

```bash
docker run --rm -it --pid container:my-fluentd \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/fluentd:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Development variants typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

### Available Fluentd variants

- **Runtime variants** (e.g., `1.19`, `1.19.0`, `1.19-debian13`): Minimal images for production use running as nonroot
  user (65532)
- **Development variants** (e.g., `1.19-dev`, `1.19.0-dev`, `1.19-debian13-dev`): Development images with shell and
  package manager for plugin installation

All variants are based on hardened Debian 13 and include Fluentd version 1.19.x.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item                | Migration note                                                                                                                                                                                                                                                |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image          | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                     |
| Package management  | Runtime variants don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                        |
| Non-root user       | By default, runtime variants run as the nonroot user (65532). Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                 |
| Multi-stage build   | Utilize images with a `dev` tag for build stages and runtime variants for runtime.                                                                                                                                                                            |
| TLS certificates    | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                            |
| Ports               | Runtime variants run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Configure Fluentd to use ports above 1024. |
| Entry point         | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                   |
| No shell            | By default, runtime variants, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                 |
| Plugin installation | Plugins must be installed in development variants during build stage and copied to runtime images.                                                                                                                                                            |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   Fluentd images are available in version 1.19.x.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   plugin installation, use an image tagged as `dev` because it has the tools needed to install packages and
   dependencies.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a runtime variant.

1. **Install additional packages**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. For Fluentd plugins,
   you must install them in the build stage using a `dev` image and copy the necessary artifacts to the runtime stage.

   Only images tagged as `dev` have package managers. Use `fluent-gem install` to add plugins in the dev stage, then
   copy the gem directories to the runtime stage.

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

### Permissions

By default image variants intended for runtime, run as the nonroot user (65532). Ensure that necessary files and
directories are accessible to the nonroot user. You may need to copy files to different directories or change
permissions so your application running as the nonroot user can access them.

For Fluentd, ensure configuration files and log directories have appropriate permissions:

```dockerfile
COPY --chown=65532:65532 fluent.conf /fluent/fluent.conf
RUN mkdir -p /var/log/fluentd && chown -R 65532:65532 /var/log/fluentd
```

### Privileged ports

Runtime variants run as a nonroot user by default. As a result, applications in these images can't bind to privileged
ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

Fluentd's default ports (9880 for HTTP, 24224 for forward) are not affected by this limitation and work without special
configuration. However, if configuring custom input sources, ensure they use ports above 1024.

**Note**: Docker Desktop may allow nonroot users to bind to privileged ports, but this behavior should not be relied
upon in production environments.

### No shell

By default, image variants intended for runtime don't contain a shell. Use development variants in build stages to run
shell commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug
containers with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.

### Plugin compatibility

When migrating custom plugins or configurations:

- Test plugin compatibility with Ruby version in DHI Fluentd
- Verify plugin dependencies are included in build stage
- Ensure file permissions are correct after copying plugins
- Use multi-stage builds to keep runtime image minimal

### Configuration file paths

Fluentd configurations may need path adjustments for the nonroot user:

- Use `/tmp` for temporary files instead of `/var/tmp`
- Ensure log file directories are writable by user 65532
- Use relative paths where possible in configuration files
