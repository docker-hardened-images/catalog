## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this SapMachine image

This Docker Hardened SapMachine image includes:

- SapMachine JDK installed under /opt/java/openjdk
- Common Java CLI tools linked into /usr/local/bin (java, javac, keytool, jcmd, jstack, jmap)
- Environment variables: JAVA_HOME, JAVA_VERSION and (in FIPS variants) additional FIPS-related variables
- Small set of minimal OS packages for runtime in non-dev variants; full package manager available in `-dev` variants
- SBOM available at /opt/docker/sbom inside the image

## Start a SapMachine image

The SapMachine DHI provides `dev` variants for build-time use and minimal runtime variants for production. Use the dev
variant when you need a shell or package manager inside the image.

### Basic usage

```bash
$ docker run --rm --name sapmachine-demo \
  dhi.io/sapmachine:<tag> java -version
```

This runs the container and executes `java -version` using the image's java binary.

### With Docker Compose (recommended for build/test workflows)

Example for runtime variant:

```yaml
version: '3.8'
services:
  app:
    image: dhi.io/sapmachine:<tag>
    container_name: sapmachine-app
    command: ["java", "-jar", "/app/myapp.jar"]
    volumes:
      - ./myapp.jar:/app/myapp.jar:ro
```

Example for dev variant:

```yaml
version: '3.8'
services:
  app:
    image: dhi.io/sapmachine:<tag>-dev
    container_name: sapmachine-app
    command: ["java", "-jar", "/app/myapp.jar"]
    volumes:
      - ./myapp.jar:/app/myapp.jar:ro
```

### Environment variables

| Variable              | Description                                                    | Default                                                                                                  | Required           |
| --------------------- | -------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ------------------ |
| `JAVA_HOME`           | Path to the SapMachine installation                            | `/opt/java/openjdk/<major>` (JDK dev variants)<br>`/opt/java/openjdk/<major>-jre` (JRE runtime variants) | Yes (set by image) |
| `JAVA_VERSION`        | SapMachine version string packaged into the image              | set in image metadata                                                                                    | No                 |
| `JAVA_FIPS_CLASSPATH` | (FIPS variant) Classpath entries required for FIPS-enabled JVM | `/opt/bouncycastle/*`                                                                                    | No                 |
| `JDK_JAVA_OPTIONS`    | (FIPS variant) Additional JVM options required for FIPS mode   | (variant specific)                                                                                       | No                 |

Example using environment variables (runtime variant):

```bash
$ docker run --rm \
  --name sapmachine-run dhi.io/sapmachine:<tag> java -jar /app/myapp.jar
```

Example using environment variables (dev variant):

```bash
$ docker run --rm \
  --name sapmachine-dev dhi.io/sapmachine:<tag>-dev /bin/bash
```

## Common SapMachine use cases

- Run a standalone Java application

  - Use the runtime variant for production. Mount your application JAR into the container and run
    `java -jar /app/myapp.jar`.

- Build artifacts in CI with a multi-stage Dockerfile

  - Use the `-dev` variant as a build stage (it contains package managers and a shell), compile/build artifacts, then
    copy only the runtime artifacts into a smaller runtime SapMachine image.

- FIPS-enabled JVM usage

  - Use the `-fips` variants if you require FIPS cryptography. These variants include BouncyCastle FIPS providers and
    additional JVM options. See the SapMachine documentation for details on FIPS configuration.

- Debugging and diagnostics

  - Use the included jcmd/jstack/jmap tools in the JDK to gather diagnostics. For runtime images without a shell, use
    Docker Debug to get an ephemeral shell for troubleshooting.

## Example: Multi-stage Dockerfile (build + runtime)

```dockerfile
# Build stage
FROM dhi.io/sapmachine:<tag>-dev AS build
WORKDIR /workspace
COPY . /workspace
RUN ./gradlew build --no-daemon

# Runtime stage
FROM dhi.io/sapmachine:<tag>
WORKDIR /app
COPY --from=build /workspace/build/libs/myapp.jar /app/myapp.jar
CMD ["java", "-jar", "/app/myapp.jar"]
```

## Configuration and persistence

SapMachine itself does not require persistent storage beyond your application's needs. Typical persistence patterns:

- Mount application configuration files or JARs as read-only volumes
- Mount log directories to the host or use a sidecar to ship logs to a central system

## Example: Docker Compose for a web service with reverse proxy

This example shows a simple setup where a Java application is run in the sapmachine image and proxied by an Nginx
reverse proxy on the host to terminate TLS. The Java app listens on 8080 inside the container.

```yaml
version: '3.8'
services:
  app:
    image: dhi.io/sapmachine:<tag>
    container_name: my-java-app
    command: ["java", "-jar", "/app/myapp.jar", "--server.port=8080"]
    volumes:
      - ./myapp.jar:/app/myapp.jar:ro
    ports:
      - "8080:8080"

  reverse-proxy:
    image: nginx:latest
    container_name: my-nginx
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    ports:
      - "443:443"
```

## Real-world CI example (GitHub Actions)

This GitHub Actions workflow builds a Java application using the sapmachine `-dev` variant and then runs tests in a
runtime container.

```yaml
name: CI

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: |
          docker run --rm -v ${GITHUB_WORKSPACE}:/workspace -w /workspace \
            dhi.io/sapmachine:<tag>-dev ./gradlew build --no-daemon
      - name: Run tests
        run: |
          docker run --rm -v ${GITHUB_WORKSPACE}:/app -w /app \
            dhi.io/sapmachine:<tag> java -jar /app/build/libs/myapp.jar
```

## Configuration files and JVM options

Place JVM options in a file and mount them into the container. For example, create a file `jvm.options` with JVM flags
and mount it into the container, then reference it when starting the JVM.

```text
-Xms512m
-Xmx1024m
-XX:MaxGCPauseMillis=200
```

Start the container with:

```bash
$ docker run --rm -v $(pwd)/jvm.options:/app/jvm.options:ro \
  dhi.io/sapmachine:<tag> sh -c 'java $(cat /app/jvm.options | xargs) -jar /app/myapp.jar'
```

Alternatively, read the file from the host before passing to docker:

```bash
$ docker run --rm dhi.io/sapmachine:<tag> java $(cat jvm.options | xargs) -jar /app/myapp.jar
```

## Notes and best practices

- Use the `-dev` tagged images for local development, CI builds, or when a shell and package manager are required.
- Always pin to specific image tags in production to avoid unexpected upgrades.
- Scan images for vulnerabilities and apply your organization's hardening practices.
- Non-dev runtime images run as a nonroot user; ensure mounted volumes and files are accessible to a nonroot UID.

## Non-hardened images vs. Docker Hardened Images

*Note any key differences for this specific image, not general differences. Any information provided in the below
boilerplate should not be repeated here.*

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

*Only include the following FIPS section if the image has a -fips variant*

- FIPS variants include `fips` in the variant name and tag. They come in both runtime and build-time variants. These
  variants use cryptographic modules that have been validated under FIPS 140, a U.S. government standard for secure
  cryptographic operations. For example, usage of MD5 fails in FIPS variants. *End of FIPS section*

To view the image variants and get more information about them, select the Tags tab for this repository, and then select
a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item                                                    | Migration note                                                                                                                                                                                                                                                                                                               |
| :------------------------------------------------------ | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image                                              | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management                                      | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user                                           | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build                                       | Utilize images with a `dev` tag for build stages and non-dev images for runtime. To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your         |
| final runtime stage should use a non-dev image variant. |                                                                                                                                                                                                                                                                                                                              |
| TLS certificates                                        | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports                                                   | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point                                             | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell                                                | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                  |

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
