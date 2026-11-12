## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## Start a Dart instance

Run the following command to run a Dart instance. Replace `<tag>` with the image variant you want to run.

```
docker run --rm dhi.io/dart:<tag> dart --version
```

Create a simple Dart program and run it directly from the container:

```
docker run --rm -v $(pwd):/app -w /app dhi.io/dart:<tag> sh -c 'cat > hello.dart << EOF
void main() {
  print("Hello from DHI Dart!");
}
EOF
dart run hello.dart'
```

## Common Dart use cases

### Build and run a Dart CLI application

Create a simple Dart console application:

#### Step 1: Create pubspec.yaml

```
cat > pubspec.yaml << EOF
name: dart_hello
description: A simple Dart CLI application
version: 1.0.0
environment:
  sdk: ^3.0.0

dependencies:
  http: ^1.1.0
EOF
```

#### Step 2: Create the application

```
mkdir -p bin
cat > bin/main.dart << EOF
import 'dart:io';

void main() async {
  final server = await HttpServer.bind('0.0.0.0', 8080);
  print('Server listening on port 8080');

  await for (final request in server) {
    request.response
      ..headers.contentType = ContentType.text
      ..write('Hello from DHI Dart!')
      ..close();
  }
}
EOF
```

#### Step 3: Create the Dockerfile

Create a Dockerfile with the following content to compile and run the project. Replace `<tag>` with the image variant
you want to run.

```Dockerfile
# syntax=docker/dockerfile:1

## -----------------------------------------------------
## Build stage
FROM dhi.io/dart:<tag> AS build-stage

WORKDIR /app
COPY pubspec.yaml ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/main.dart -o /app/server

## -----------------------------------------------------
## Runtime stage - use static or minimal image
FROM dhi.io/dart:<tag> AS runtime-stage

WORKDIR /app
COPY --from=build-stage /app/server /app/server

EXPOSE 8080
CMD ["/app/server"]
```

You can then build and run the Docker image:

```
docker build -t my-dart-app .
docker run -d -p 8080:8080 --name my-dart-app my-dart-app

# Test the server
curl http://localhost:8080/

# Clean up
docker stop my-dart-app && docker rm my-dart-app
```

### Compile your app inside the Docker container

There may be occasions where it is not appropriate to run your app inside a container. To compile, but not run your app
inside the Docker instance, you can write something like:

```
docker run --rm \
  -v "$PWD":/app \
  -w /app \
  dhi.io/dart:<tag> \
  dart compile exe bin/main.dart -o my-app
```

This will add your current directory as a volume to the container, set the working directory to the volume, and run the
`dart compile exe` command which will compile the project and output the executable to `my-app`.

### Run Dart package commands

You can use the Dart package manager to install dependencies and run commands:

```
# Get dependencies
docker run --rm -v "$PWD":/app -w /app dhi.io/dart:<tag> dart pub get

# Run tests
docker run --rm -v "$PWD":/app -w /app dhi.io/dart:<tag> dart test

# Analyze code
docker run --rm -v "$PWD":/app -w /app dhi.io/dart:<tag> dart analyze
```

## Image variants

Docker Hardened Images come in different variants depending on their intended use.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as the nonroot user
  - Do not include a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the variant name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                   |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For compiled executables, consider using a minimal runtime image.                                                                                                                                                                           |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                                  |
| No shell           | Some images, such as static, don't contain a shell. Use dev images in build stages to run shell commands and then copy artifacts to the runtime stage.                                                                                                                                                                       |

The following steps outline the general migration process.

1. Find hardened images for your app.

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. Update the base image in your Dockerfile.

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step. For Dart
   applications, this is typically going to be an image with the Dart SDK.

1. For multi-stage Dockerfiles, update the runtime image in your Dockerfile.

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. Use Dart images for compilation and consider a minimal runtime for the final
   compiled executable.

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

By default image variants intended for runtime, run as a nonroot user. Ensure that necessary files and directories are
accessible to that user. You may need to copy files to different directories or change permissions so your application
running as a nonroot user can access them.

To view the user for an image variant, select the **Images** tab for this repository in the DHI catalog.

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

To see if a shell is available in an image variant and which one, select the **Images** tab for this repository in the
DHI catalog.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** or **Images** tab for this repository,
select a tag, and then select the **Specifications** tab.
