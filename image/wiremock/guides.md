## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a WireMock image

Run the following command to start WireMock with default settings:

```bash
$ docker run -d --name wiremock -p 8080:8080 dhi.io/wiremock:<tag>
```

WireMock will start on port 8080. WireMock doesn't serve content at the root path `/` by default. To verify WireMock is
running, access the admin API at `http://localhost:8080/__admin/mappings` or the Swagger UI at
`http://localhost:8080/__admin/swagger-ui/`.

### Environment variables

WireMock supports configuration through environment variables:

| Variable    | Description                 | Default | Required |
| ----------- | --------------------------- | ------- | -------- |
| `JAVA_HOME` | Java installation directory | Auto    | No       |

> **Note:** The following environment variables from the upstream Docker image do not work in DHI images because they
> are processed by the upstream shell script entrypoint, which is not present in hardened images:
>
> - `JAVA_OPTS` - See [Customizing Java options](#customizing-java-options) for how to pass JVM options manually.
> - `WIREMOCK_OPTIONS` - See [Customizing WireMock options](#customizing-wiremock-options) for how to pass WireMock
>   options manually.

### Customizing Java options

Since the runtime image does not include a shell, `JAVA_OPTS` environment variables are not automatically processed. To
pass JVM options, override the command:

```bash
$ docker run -d --name wiremock \
  -p 8080:8080 \
  dhi.io/wiremock:<tag> \
  -Xmx512m -Xms256m -jar /usr/local/bin/wiremock-standalone.jar
```

### Customizing WireMock options

Since the runtime image does not include a shell, `WIREMOCK_OPTIONS` environment variables are not automatically
processed. To pass WireMock-specific options, override the command:

```bash
$ docker run -d --name wiremock \
  -p 8080:8080 \
  dhi.io/wiremock:<tag> \
  -jar /usr/local/bin/wiremock-standalone.jar --port 8080 --verbose
```

### Combining Java and WireMock options

To pass both JVM options and WireMock options, override the command with all arguments:

```bash
$ docker run -d --name wiremock \
  -p 8080:8080 \
  dhi.io/wiremock:<tag> \
  -Xmx512m -Xms256m -jar /usr/local/bin/wiremock-standalone.jar --port 8080 --verbose
```

### Health checks

WireMock provides a health endpoint at `/__admin/health` that can be used for container health checks.

#### Docker Compose

Since Docker Hardened Images don't include `curl` in runtime variants, Docker Compose health checks that require curl
are not supported. Instead, use one of these approaches:

**Option 1: Use a sidecar container with busybox for monitoring:**

```yaml
services:
  wiremock:
    image: dhi.io/wiremock:<tag>
    ports:
      - "8080:8080"

  # Sidecar container for health monitoring
  wiremock-healthcheck:
    image: dhi.io/busybox:1
    depends_on:
      - wiremock
    command: ["sh", "-c", "while true; do wget -q -O- http://wiremock:8080/__admin/health || exit 1; sleep 30; done"]
    restart: unless-stopped
```

**Option 2: Use external monitoring tools** that can perform HTTP health checks without requiring curl inside the
container.

#### Kubernetes

Use HTTP probes for liveness and readiness checks:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: wiremock
spec:
  containers:
    - name: wiremock
      image: dhi.io/wiremock:<tag>
      ports:
        - containerPort: 8080
      livenessProbe:
        httpGet:
          path: /__admin/health
          port: 8080
        initialDelaySeconds: 30
        periodSeconds: 10
        timeoutSeconds: 5
        failureThreshold: 3
      readinessProbe:
        httpGet:
          path: /__admin/health
          port: 8080
        initialDelaySeconds: 10
        periodSeconds: 5
        timeoutSeconds: 3
        failureThreshold: 3
```

## Common WireMock use cases

### Basic API mocking

Start WireMock and create a stub mapping:

```bash
# Start WireMock
$ docker run -d --name wiremock -p 8080:8080 dhi.io/wiremock:<tag>

# Create a stub mapping
$ curl -X POST http://localhost:8080/__admin/mappings \
  -H "Content-Type: application/json" \
  -d '{
    "request": {
      "method": "GET",
      "url": "/api/test"
    },
    "response": {
      "status": 200,
      "body": "Hello from WireMock"
    }
  }'

# Test the stub
$ curl http://localhost:8080/api/test
```

### WireMock with persistence

WireMock stores stub mappings and files in `/home/wiremock`. Mount this directory to persist data:

```bash
$ docker run -d --name wiremock \
  -p 8080:8080 \
  -v wiremock-data:/home/wiremock \
  dhi.io/wiremock:<tag>
```

The directory structure:

- `/home/wiremock/mappings/` - Stub mappings (JSON files)
- `/home/wiremock/__files/` - Response body files

### Recording from a real API

Use WireMock's record mode to capture requests and responses:

```bash
$ docker run -d --name wiremock \
  -p 8080:8080 \
  dhi.io/wiremock:<tag> \
  -jar /usr/local/bin/wiremock-standalone.jar --proxy-all=https://api.example.com --record-mappings
```

### Using pre-configured mappings

Mount a directory with your stub mappings:

```bash
$ docker run -d --name wiremock \
  -p 8080:8080 \
  -v $(pwd)/mappings:/home/wiremock/mappings \
  dhi.io/wiremock:<tag>
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the FROM image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For
   framework images, this is typically going to be an image tagged as `dev` because it has the tools needed to install
   packages and dependencies.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. Install additional packages

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. You may need to
   install additional packages in your Dockerfile. Inspect the image variants to identify which packages are already
   installed.

   Only images tagged as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the
   packages. Install the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary
   artifacts to the runtime stage that uses a non-dev image.

   For Alpine-based images, you can use `apk` to install packages. For Debian-based images, you can use `apt-get` to
   install packages.

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

The DHI WireMock image runs `java` directly with `-jar /usr/local/bin/wiremock-standalone.jar`, rather than using a
shell script like the upstream image. This means:

- Standard usage works identically to upstream
- WireMock functionality is unchanged
- `JAVA_OPTS` and `WIREMOCK_OPTIONS` environment variables have no effect (see the note in
  [Environment variables](#environment-variables))
- The upstream `uid` environment variable feature (for user switching via gosu) is not available in DHI images. DHI
  images run as nonroot user by default, so this feature is typically unnecessary.
