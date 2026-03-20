## How to use this image

All examples in this guide use the public image. If you’ve mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### Run JMX Exporter

By default, this image runs JMX Exporter in standalone mode (an external process that connects to your JVM application
using RMI). Standalone mode supports both HTTP (default) and OpenTelemetry output, which you can configure in your JMX
Exporter configuration file. See the [upstream documentation](https://prometheus.github.io/jmx_exporter/) for details.

The image runs with the default entrypoint of `java -jar jmx_prometheus_standalone.jar`, and default command of
`5556 examples/standalone_sample_config.yml`. This configuration file is an example included with the image for
demonstration.

To run it, use the following command.

```
$ docker run --rm -p 5556:5556 dhi.io/jmx-exporter:<tag>
```

### Run in standalone mode with a custom configuration

To run the JMX Exporter with your configuration, you can use the following command.

```
$ docker run --rm -p 5556:5556 \
   -v /path/to/your/jmx_exporter_config.yaml:/etc/jmx_exporter_config.yaml \
   dhi.io/jmx-exporter:<tag> \
   5556 /etc/jmx_exporter_config.yaml
```

This command binds the host port 5556 to the container port 5556 and mounts your JMX Exporter configuration file into
the container.

You can `curl localhost:5556/metrics` to verify that the JMX Exporter is running and exposing metrics, or
`curl localhost:5556/-/healthy` to check its health.

### Run JMX Exporter as a Java Agent

In addition to standalone mode, the image includes the Java Agent at `/opt/jmx-exporter/jmx_prometheus_javaagent.jar`.
You can copy this into your own image or create a customized DHI with the agent added, and run JMX Exporter as a Java
agent inside your application process. The Java Agent supports both HTTP (default) and OpenTelemetry output modes, which
are enabled and configured in your JMX Exporter configuration file. See the
[upstream documentation](https://prometheus.github.io/jmx_exporter/) for details.

### Use Compose to run JMX Exporter

To run the JMX Exporter with Docker Compose, you can use the following example `compose.yaml` file as a starting point.

```yaml
services:
  jmx-exporter:
    image: dhi.io/jmx-exporter:<tag>
    container_name: jmx-exporter
    ports:
      - "5556:5556"
    volumes:
      - ./config.yaml:/opt/jmx-exporter/config.yaml
    command:
      - "5556"
      - config.yaml
    networks:
      - metrics
  example-app:
    build: ./SimpleJMXApp
    container_name: example-app
    ports:
      - "9999:9999"
    command:
      - "java"
      - "-classpath"
      - "."
      - "-Dcom.sun.management.jmxremote=true"
      - "-Dcom.sun.management.jmxremote.authenticate=false"
      - "-Dcom.sun.management.jmxremote.local.only=false"
      - "-Dcom.sun.management.jmxremote.ssl=false"
      - "-Dcom.sun.management.jmxremote.port=9999"
      - "-Dcom.sun.management.jmxremote.rmi.port=9999"
      - "-Djava.rmi.server.hostname=example-app"
      - "SimpleJMXApp"
    networks:
      - metrics

networks:
  metrics:
    driver: bridge
```

This example `compose.yaml` file defines two services: `jmx-exporter` and `example-app`. The `jmx-exporter` service runs
the JMX Exporter, while the `example-app` service runs a simple Java application that exposes JMX metrics. The JMX
Exporter is configured to listen on port 5556, and the example application is configured to expose JMX metrics on port
9999\.

## Image variants

Docker Hardened Images come in different variants depending on their intended use. Image variants are identified by
their tag.

- Runtime variants are designed to run your application in production. These images are intended to be used either
  directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

  - Run as a nonroot user
  - Do not include a shell or a package manager
  - Contain only the minimal set of libraries needed to run the app

- Build-time variants typically include `dev` in the tag name and are intended for use in the first stage of a
  multi-stage Dockerfile. These images typically:

  - Run as the root user
  - Include a shell and package manager
  - Are used to build or compile applications

To view the image variants and get more information about them, select the **Tags** tab for this repository, and then
select a tag.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile. At minimum, you must update the
base image in your existing Dockerfile to a Docker Hardened Image. This and a few other common changes are listed in the
following table of migration notes.

| Item               | Migration note                                                                                                                                                                                                                                                                                                               |
| :----------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                    |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                                  |
| Nonroot user       | By default, non-dev images, intended for runtime, run as a nonroot user. Ensure that necessary files and directories are accessible to that user.                                                                                                                                                                            |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                                                                                                                                                   |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                           |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can’t bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
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
   install additional packages in your Dockerfile. To view if a package manager is available for an image variant,
   select the **Tags** tab for this repository. To view what packages are already installed in an image variant, select
   the **Tags** tab for this repository, and then select a tag.

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

To view the user for an image variant, select the **Tags** tab for this repository.

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

To see if a shell is available in an image variant and which one, select the **Tags** tab for this repository.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images.

To view the Entrypoint or CMD defined for an image variant, select the **Tags** tab for this repository, select a tag,
and then select the **Specifications** tab.
