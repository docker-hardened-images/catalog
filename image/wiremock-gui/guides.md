## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a WireMock GUI image

Run the following command to start WireMock GUI with default settings:

```bash
$ docker run -d --name wiremock-gui -p 8080:8080 dhi.io/wiremock-gui:<tag>
```

WireMock GUI will start on port 8080. WireMock doesn't serve content at the root path `/` by default. To verify the
container is running, access the admin API at `http://localhost:8080/__admin/mappings`, the Swagger UI at
`http://localhost:8080/__admin/swagger-ui/`, or the GUI at `http://localhost:8080/__admin/webapp`.

## Accessing the admin GUI

WireMock GUI exposes an Angular admin webapp at `http://localhost:8080/__admin/webapp`. After starting the container,
open that URL in a browser to access:

- **Stub mappings** — create, edit, and delete request/response stubs interactively.
- **Request log** — browse matched and unmatched requests live.
- **Recordings** — start/stop recording sessions and inspect captured interactions.
- **Files** — manage response body files under `/home/wiremock/__files/`.

The standard WireMock admin API at `/__admin/*` remains fully available for programmatic access, so existing scripts and
CI integrations that target the upstream `wiremock/wiremock` image continue to work unchanged.

### Environment variables

WireMock GUI supports configuration through environment variables:

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
$ docker run -d --name wiremock-gui \
  -p 8080:8080 \
  dhi.io/wiremock-gui:<tag> \
  -Xmx512m -Xms256m -jar /usr/local/bin/wiremock-standalone.jar
```

### Customizing WireMock options

Since the runtime image does not include a shell, `WIREMOCK_OPTIONS` environment variables are not automatically
processed. To pass WireMock-specific options, override the command:

```bash
$ docker run -d --name wiremock-gui \
  -p 8080:8080 \
  dhi.io/wiremock-gui:<tag> \
  -jar /usr/local/bin/wiremock-standalone.jar --port 8080 --verbose
```

### Combining Java and WireMock options

To pass both JVM options and WireMock options, override the command with all arguments:

```bash
$ docker run -d --name wiremock-gui \
  -p 8080:8080 \
  dhi.io/wiremock-gui:<tag> \
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
  wiremock-gui:
    image: dhi.io/wiremock-gui:<tag>
    ports:
      - "8080:8080"

  # Sidecar container for health monitoring
  wiremock-healthcheck:
    image: dhi.io/busybox:1
    depends_on:
      - wiremock-gui
    command: ["sh", "-c", "while true; do wget -q -O- http://wiremock-gui:8080/__admin/health || exit 1; sleep 30; done"]
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
  name: wiremock-gui
spec:
  containers:
    - name: wiremock-gui
      image: dhi.io/wiremock-gui:<tag>
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

Start WireMock GUI and create a stub mapping:

```bash
# Start WireMock GUI
$ docker run -d --name wiremock-gui -p 8080:8080 dhi.io/wiremock-gui:<tag>

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
$ docker run -d --name wiremock-gui \
  -p 8080:8080 \
  -v wiremock-data:/home/wiremock \
  dhi.io/wiremock-gui:<tag>
```

The directory structure:

- `/home/wiremock/mappings/` - Stub mappings (JSON files)
- `/home/wiremock/__files/` - Response body files

### Recording from a real API

Use WireMock's record mode to capture requests and responses:

```bash
$ docker run -d --name wiremock-gui \
  -p 8080:8080 \
  dhi.io/wiremock-gui:<tag> \
  -jar /usr/local/bin/wiremock-standalone.jar --proxy-all=https://api.example.com --record-mappings
```

### Using pre-configured mappings

Mount a directory with your stub mappings:

```bash
$ docker run -d --name wiremock-gui \
  -p 8080:8080 \
  -v $(pwd)/mappings:/home/wiremock/mappings \
  dhi.io/wiremock-gui:<tag>
```

## FIPS variant

The `-fips` and `-fips-dev` variants run on a FIPS-certified Eclipse Temurin JRE and configure the JVM to use
BouncyCastle FIPS cryptographic modules (bc-fips, bctls-fips, bcutil-fips, bc-rng-jent, bcpkix-fips). FIPS mode is
activated via `JDK_JAVA_OPTIONS=@/etc/wiremock/wiremock-fips.properties`, which is set automatically when you use a
`-fips` tag. In this mode all JVM crypto operations and outbound/client TLS (for example HTTPS proxying, and certificate
verification via the BCFKS trust store) route through the BouncyCastle FIPS provider in approved-only mode.

### Limitation: serving HTTPS under FIPS

Serving inbound HTTPS (`--https-port`) is not supported on the `-fips` variants in approved-only mode. WireMock's
built-in HTTPS keystore is a JKS, which approved-only rejects, and even with a BCFKS server keystore the BouncyCastle
JSSE server-side TLS handshake does not complete (the server closes the connection before the ServerHello). The FIPS
variants still serve plain HTTP normally and apply FIPS crypto to all in-process operations and outbound TLS. If you
need to serve HTTPS:

- use a non-FIPS variant, or
- run the `-fips` runtime variant behind a FIPS-validated reverse proxy or service-mesh sidecar that terminates TLS,
  forwarding plain HTTP to WireMock.

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

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants.

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

The DHI WireMock GUI image runs `java` directly with `-jar /usr/local/bin/wiremock-standalone.jar`, rather than using a
shell script like the upstream image. This means:

- Standard usage works identically to upstream
- WireMock functionality (including the embedded Angular GUI at `/__admin/webapp`) is unchanged
- `JAVA_OPTS` and `WIREMOCK_OPTIONS` environment variables have no effect (see the note in
  [Environment variables](#environment-variables))
- The upstream `uid` environment variable feature (for user switching via gosu) is not available in DHI images. DHI
  images run as nonroot user by default, so this feature is typically unnecessary.
