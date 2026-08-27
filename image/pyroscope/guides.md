## Prerequisites

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a pyroscope instance

Run the following commands.

```bash
# Create a Docker network for Pyroscope and related services
$ docker network create pyroscope-demo

# Start Pyroscope server
$ docker run -d \
  --name pyroscope \
  --network pyroscope-demo \
  -p 4040:4040 \
  dhi.io/pyroscope:<tag>

# Verify Pyroscope is running
$ curl http://localhost:4040/ready
# Output: ready

# Clean up after testing
$ docker rm -f pyroscope
$ docker network rm pyroscope-demo
```

> **Note:** The Docker Hardened Image for Pyroscope does not include the embedded web UI available in the upstream
> Grafana Pyroscope image. This is intentional to reduce attack surface. Use Grafana with the Pyroscope data source for
> visualization, or query the API directly.

## Common pyroscope use cases

### With persistent storage

Run Pyroscope with persistent data storage:

```bash
# Create network and volume
$ docker network create pyroscope-demo
$ docker volume create pyroscope-data

# Start Pyroscope with persistent storage
$ docker run -d \
  --name pyroscope \
  --network pyroscope-demo \
  -p 4040:4040 \
  -v pyroscope-data:/data \
  dhi.io/pyroscope:<tag>

# Clean up (keeps volume for data persistence)
$ docker rm -f pyroscope
$ docker network rm pyroscope-demo
# To also remove data: docker volume rm pyroscope-data
```

### With Grafana for visualization

Since the DHI image doesn't include the web UI, use Grafana to visualize profiling data:

```bash
# Create network
$ docker network create pyroscope-demo

# Start Pyroscope
$ docker run -d \
  --name pyroscope \
  --network pyroscope-demo \
  -p 4040:4040 \
  dhi.io/pyroscope:<tag>

# Start Grafana
$ docker run -d \
  --name grafana \
  --network pyroscope-demo \
  -p 3000:3000 \
  dhi.io/grafana:<tag>

# Access Grafana at http://localhost:3000 (admin/admin)
# Add Data Source → Grafana Pyroscope → URL: http://pyroscope:4040

# Clean up
$ docker rm -f pyroscope grafana
$ docker network rm pyroscope-demo
```

### Docker Compose deployment

Complete monitoring stack with Pyroscope and Grafana:

```yaml
services:
  pyroscope:
    image: dhi.io/pyroscope:<tag>
    container_name: pyroscope
    ports:
      - "4040:4040"
      - "9095:9095"
    volumes:
      - pyroscope-data:/data
    networks:
      - pyroscope-demo
    restart: unless-stopped

  grafana:
    image: dhi.io/grafana:<tag>
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
    networks:
      - pyroscope-demo
    depends_on:
      - pyroscope
    restart: unless-stopped

networks:
  pyroscope-demo:
    driver: bridge

volumes:
  pyroscope-data:
```

Save as `docker-compose.yml` and run:

```bash
$ docker compose up -d

# Access:
# - Pyroscope API: http://localhost:4040
# - Grafana UI: http://localhost:3000

# In Grafana, add Pyroscope data source with URL: http://pyroscope:4040

# Clean up
$ docker compose down
# To also remove volumes: docker compose down -v
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Docker Official pyroscope           | Docker Hardened pyroscope                           |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Web UI          | Embedded web interface included     | No web UI (use Grafana instead)                     |
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

```bash
$ docker debug pyroscope
```

or mount debugging tools with the Image Mount feature:

```bash
$ docker run --rm -it --pid container:pyroscope \
  --mount=type=image,source=dhi.io/busybox,destination=/dbg,ro \
  dhi.io/pyroscope:<tag> /dbg/bin/sh
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

**Runtime variants** are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

**Build-time variants** typically include `dev` in the variant name and are intended for use in the first stage of a
multi-stage Dockerfile. These images typically:

- Run as the root user
- Include a shell and package manager
- Are used to build or compile applications

Pyroscope DHI only provides runtime variants. There are no `dev` or `fips` tagged images available. The runtime image is
sufficient for production deployments as Pyroscope is a standalone binary that doesn't require build-time compilation.

FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes:

| Item               | Migration note                                                                                                                                                                              |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                   |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                   |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                  |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                      |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                          |
| Ports              | Non-dev hardened images run as a nonroot user by default. Pyroscope default port 4040 works without issues.                                                                                 |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary. |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                 |
| Web UI             | The DHI image does not include the embedded web UI. Use Grafana with Pyroscope data source for visualization.                                                                               |

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

1. **Set up visualization**

   Since the DHI image doesn't include the web UI, configure Grafana with the Pyroscope data source to visualize
   profiling data.

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
