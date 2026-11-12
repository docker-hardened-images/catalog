## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this harbor-jobservice image

This image contains Harbor Job Service, the asynchronous task execution engine for Harbor registry. The entry point for
the image is `/usr/local/bin/harbor-jobservice` which provides background job processing for operations such as image
replication, garbage collection, vulnerability scanning, and tag retention.

## Start a harbor-jobservice instance

> **Note:** The harbor-jobservice image is designed to run as part of a Harbor deployment in Kubernetes, requiring Redis
> for job queue management and Harbor Core for job scheduling. The standalone Docker command below displays the
> available configuration options.

```bash
docker run --rm -it <your-namespace>/dhi-harbor-jobservice:<tag> -h
```

## Common harbor-jobservice use cases

### Run with configuration

`harbor-jobservice` requires a configuration file and connection to Redis and Harbor Core. This is especially useful in
Harbor deployments for background task processing.

```bash
# Run with configuration file (daemon mode with port mapping)
docker run -d --name harbor-jobservice \
  -p 8080:8080 \
  -v /path/to/config.yml:/etc/jobservice/config.yml \
  -v /path/to/logs:/var/log/jobs \
  --network harbor-network \
  <your-namespace>/dhi-harbor-jobservice:<tag>

# Health check endpoint test
curl http://localhost:8080/api/v1/stats
```

### Available harbor-jobservice options

The harbor-jobservice service provides these configuration options:

```bash
# Main Options:
# -c <path>        - Path to configuration file (required)
# -h               - Show help information

# Configuration file format (YAML):
# protocol         - Communication protocol (http/https)
# port             - Service port
# worker_pool      - Worker configuration and Redis connection
# job_loggers      - Logging configuration for jobs
# loggers          - Service logging configuration

# Test API endpoints
curl http://localhost:8080/api/v1/stats
```

### Harbor deployment integration

`harbor-jobservice` is a critical background processing component of Harbor deployments. Here's how to integrate with
Helm:

```yaml
# Override Harbor chart to use DHI image in values.yaml
jobservice:
  image:
    repository: <your-namespace>/dhi-harbor-jobservice
    tag: <tag>
    pullPolicy: IfNotPresent
```

```bash
# Helm install with DHI harbor-jobservice
# Currently Harbor does not provide arm64 compatible images, so only amd64
# deployments are possible.
helm install my-harbor oci://helm.goharbor.io/harbor \
  --set jobservice.image.repository=<your-namespace>/dhi-harbor-jobservice \
  --set jobservice.image.tag=<tag>
```

### Local development and testing

Use `harbor-jobservice` for local development and testing:

```bash
# Run with minimal config for testing
docker run --rm \
  -v $(pwd)/config.yml:/etc/jobservice/config.yml \
  --network harbor-network \
  <your-namespace>/dhi-harbor-jobservice:<tag>

# Show help
docker run --rm <your-namespace>/dhi-harbor-jobservice:<tag> -h

# Test with port mapping for API access
docker run -d --name harbor-jobservice-test \
  -p 8080:8080 \
  -v $(pwd)/config.yml:/etc/jobservice/config.yml \
  -v $(pwd)/logs:/var/log/jobs \
  --network harbor-network \
  <your-namespace>/dhi-harbor-jobservice:<tag>

# Check stats endpoint
curl http://localhost:8080/api/v1/stats
```

## Non-hardened images vs Docker Hardened Images

### Key differences

| Feature         | Non-hardened harbor-jobservice      | Docker Hardened harbor-jobservice                   |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened base with security patches        |
| Shell access    | Full shell (bash/sh) available      | No shell in runtime variants                        |
| Package manager | apt/apk available                   | No package manager in runtime variants              |
| User            | Runs as root by default             | Runs as nonroot user                                |
| Attack surface  | Larger due to additional utilities  | Minimal, only essential components                  |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |

### Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- Reduced attack surface: Fewer binaries mean fewer potential vulnerabilities
- Immutable infrastructure: Runtime containers shouldn't be modified after deployment
- Compliance ready: Meets strict security requirements for regulated environments

### Hardened image debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. Common debugging methods for
applications built with Docker Hardened Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools
- Ecosystem-specific debugging approaches

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session.

For example, you can use Docker Debug:

```
docker debug <your-namespace>/dhi-harbor-jobservice
```

or mount debugging tools with the Image Mount feature:

```
docker run --rm -it --pid container:my-container \
  --mount=type=image,source=<your-namespace>/dhi-busybox,destination=/dbg,ro \
  <your-namespace>/dhi-harbor-jobservice:<tag> /dbg/bin/sh
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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Kubernetes manifests or Docker
configurations. At minimum, you must update the base image in your existing deployment to a Docker Hardened Image. This
and a few other common changes are listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                                            |
| ------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Kubernetes manifests with a Docker Hardened Image.                                                                                                       |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a dev tag.                                                                 |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                |
| Multi-stage build  | Utilize images with a dev tag for build stages and non-dev images for runtime. For binary executables, use a static image for runtime.                                                    |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                        |
| Ports              | Non-dev hardened images run as a nonroot user by default. `harbor-jobservice` typically binds to port 8080 for HTTP. Because hardened images run as nonroot, avoid privileged operations. |
| Entry point        | Docker Hardened Images may have different entry points than standard images. The DHI harbor-jobservice entry point is `/usr/local/bin/harbor-jobservice -c /etc/jobservice/config.yml`.   |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.               |
| Environment config | When using harbor-jobservice in containers, ensure proper configuration file is mounted and Redis/Harbor Core connectivity is configured.                                                 |

The following steps outline the general migration process.

1. **Find hardened images for your Harbor deployment.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.
   The harbor-jobservice is the background task execution component of Harbor deployments, handling asynchronous
   operations like replication and scanning.

1. **Update your Harbor Helm chart configurations.**

   Update the image references in your Helm values or Harbor deployment configurations to use the hardened images:

   - From: `goharbor/harbor-jobservice:<tag>`
   - To: `<your-namespace>/dhi-harbor-jobservice:<tag>`

1. **For custom Harbor deployments, update the base image in your manifests.**

   If you're building custom Harbor deployments, ensure that your jobservice pod uses the hardened harbor-jobservice as
   the main container image.

1. **Update configuration file mounting.**

   Ensure your deployments properly mount the jobservice configuration file at `/etc/jobservice/config.yml` and that the
   configuration includes proper Redis connection settings and worker pool configuration.

1. **Test Harbor job execution.**

   After migration, verify that Harbor background jobs execute correctly with the hardened image. Test replication jobs,
   garbage collection, and vulnerability scanning operations. Check the `/api/v1/stats` endpoint for job service health.

## Troubleshoot migration

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

`harbor-jobservice` requires read access to the configuration file and write access to log directories. Ensure your
mounted volumes and network connectivity allow the nonroot user to access required services when running in containers.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. Harbor
jobservice typically uses port 8080 which is not privileged.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
