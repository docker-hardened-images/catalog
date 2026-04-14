## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Run a Gradle task

Run this from the directory of the Gradle project you want to build. Replace `<gradle-task>` with the Gradle task you
want to run.

```console
$ docker run --rm -v "$(pwd)":/build dhi.io/gradle:<tag> <gradle-task>
```

## Common Gradle use cases

### Create a sample Gradle project

To explore the following examples, you can use your own app, or create a sample Gradle project using the Docker Hardened
Gradle image. This approach uses bind mounts and is compatible with all the use cases in this guide.

First, create an empty directory for the project:

```console
$ mkdir gradle-demo && cd gradle-demo
```

Then, initialize a new Gradle application project using the Docker image:

```console
$ docker run --rm -v "$(pwd)":/build dhi.io/gradle:<tag> \
  init --type java-application --dsl kotlin --test-framework junit \
  --project-name gradle-demo --package org.example
```

You now have a complete Gradle project to use with the examples in this guide.

### Build a project

You can build a local project by bind mounting your project directory into the container and running the `build` task.

```console
$ docker run --rm \
  -v "$(pwd)":/build \
  dhi.io/gradle:<tag> \
  build
```

### Build and package application artifacts

You can create executable JAR files by running the `assemble` task. This task compiles your code and packages it into
JAR or WAR files, depending on your project configuration.

```console
$ docker run --rm \
  -v "$(pwd)":/build \
  dhi.io/gradle:<tag> \
  clean assemble
```

### Multi-stage Dockerfile builds

Docker Hardened Images for Gradle are build-only tools. They contain no runtime variants because Gradle builds
applications but doesn't run them. You must use multi-stage Dockerfiles to copy build artifacts to appropriate runtime
images.

The following example uses the Docker Hardened Image for Eclipse Temurin as the runtime stage.

```dockerfile
# syntax=docker/dockerfile:1
# Build stage - Gradle DHI for building
FROM dhi.io/gradle:<tag> AS build

# Copy Gradle files for better caching (working directory is /build by default)
COPY settings.gradle.kts ./
COPY app/build.gradle.kts app/
COPY gradlew gradlew.bat ./
COPY gradle/ gradle/
COPY app/src app/src

# Build the application
RUN --mount=type=cache,target=/home/gradle/.gradle \
    gradle clean assemble --no-daemon

# Runtime stage - JRE for running the application
FROM dhi.io/eclipse-temurin:<tag> AS runtime

WORKDIR /app
COPY --from=build /build/app/build/libs/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-cp", "app.jar", "org.example.App"]
```

## Non-hardened images vs. Docker Hardened Images

The following table summarizes the key differences between standard Docker Gradle images and Docker hardened Gradle
images.

| Feature         | Docker Official Image               | Docker Hardened Image                               |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Custom hardened Debian/Alpine with security patches |
| Package manager | Full package managers (apt, apk)    | Package managers only in Alpine variants            |
| Attack surface  | Large                               | Minimal                                             |
| Utilities       | Full dev toolchain                  | Minimal (Gradle, JDK, core tools only)              |
| Debugging       | Traditional shell debugging         | Use Docker Debug or entrypoint override             |

## Image variants

Docker Hardened Images come in different variants depending on their intended use. The Gradle Docker Hardened Images are
intended for build-time only. All variants include `dev` in the tag name and are designed for use in build stages of
multi-stage Dockerfiles.

## Migrate to a Docker Hardened Image

Switching to the hardened Gradle image does not require any special changes. You can use it as a drop-in replacement for
the standard Gradle image in your existing workflows and configurations. Note that the entry point for the hardened
image may differ from a standard image, so ensure that your commands and arguments are compatible.

### Migration steps

1. Update your image reference. Replace the image reference in your Docker run command, Dockerfile, or Compose file:
   - From: `gradle:<tag>`
   - To: `dhi.io/gradle:<tag>`
1. All your existing environment variables, volume mounts, and network settings remain the same.

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

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
