## Prerequisites

- Before you can use any Docker Hardened Image, you must mirror the image repository from the catalog to your
  organization. To mirror the repository, select either **Mirror to repository** or **View in repository > Mirror to
  repository**, and then follow the on-screen instructions.
- To use the code snippets in this guide, replace `<your-namespace>` with your organization's namespace and `<tag>` with
  the image variant you want to run.

## What's included in this eclipse-mosquitto image

This Docker Hardened mosquitto image includes:

- Eclipse Mosquitto broker daemon (mosquitto)
- Command-line clients: mosquitto_pub, mosquitto_sub, mosquitto_rr
- Utilities: mosquitto_passwd, mosquitto_ctrl
- Default configuration: /mosquitto/config/mosquitto.conf

## Start a eclipse-mosquitto image

The image runs the Mosquitto broker with the default configuration file at /mosquitto/config/mosquitto.conf. Adjust the
configuration by mounting your own mosquitto.conf and related files.

### Basic usage

```bash
$ docker run -d --name mosquitto -p 1883:1883 -p 9001:9001 \
  -v /path/to/conf:/mosquitto/config \
  -v /path/to/data:/mosquitto/data \
  -v /path/to/log:/mosquitto/log \
  <your-namespace>/dhi-eclipse-mosquitto:<tag>
```

- Ports commonly used by Mosquitto:
  - 1883: MQTT (insecure/plaintext)
  - 8883: MQTT over TLS (when configured)
  - 9001: MQTT over WebSockets (when enabled in config)

### With Docker Compose (production-like setup)

```yaml
version: '3.8'
services:
  mosquitto:
    image: <your-namespace>/dhi-eclipse-mosquitto:<tag>
    container_name: dhi-eclipse-mosquitto
    restart: unless-stopped
    ports:
      - "1883:1883"
      - "9001:9001"
    volumes:
      - ./config:/mosquitto/config:ro
      - ./data:/mosquitto/data
      - ./log:/mosquitto/log
    environment:
      - TZ=UTC
```

Mount a custom config directory (./config) that contains mosquitto.conf and any password/certs you need. Use :ro for
config to prevent accidental modification by the container.

### Environment variables

Mosquitto's official image relies primarily on configuration files rather than environment variables. The DHI mosquitto
image follows the same pattern: configure the broker via /mosquitto/config/mosquitto.conf and supporting files (password
file, TLS certs, etc.). Common container environment variables you may set:

| Variable | Description                            | Default   | Required |
| -------- | -------------------------------------- | --------- | -------- |
| TZ       | Timezone for logs and system utilities | UTC       | No       |
| VERSION  | Image/version (used by tests)          | image tag | No       |

## Common mosquitto use cases

### Local development broker

Run a transient broker for testing clients locally. Use a mounted config with anonymous access enabled or create a
simple password file.

```bash
# start a local broker with default config
docker run -d --name local-mosq -p 1883:1883 \
  -v $(pwd)/config:/mosquitto/config \
  <your-namespace>/dhi-eclipse-mosquitto:<tag>

# publish a test message
docker run --rm eclipse/mosquitto mosquitto_pub -h host.docker.internal -t test/topic -m "hello"
```

Note: Above publisher uses upstream image for convenience; in DHI examples prefer
<your-namespace>/dhi-eclipse-mosquitto:<tag>.

### Persistent broker with authentication and TLS

1. Create a configuration directory with mosquitto.conf that enables persistence, listeners, and TLS settings. 2.
   Generate TLS certificates and place them under the config directory (e.g., certs/). 3. Create a password file with
   mosquitto_passwd and mount it into the config directory. 4. Start using Docker Compose example above, mapping ports
   for MQTT and WebSockets as needed.

Example mosquitto.conf snippets (place into ./config/mosquitto.conf):

```
# listener for plaintext MQTT
listener 1883
allow_anonymous false
password_file /mosquitto/config/passwordfile

# TLS listener
listener 8883
cafile /mosquitto/config/certs/ca.crt
certfile /mosquitto/config/certs/server.crt
keyfile /mosquitto/config/certs/server.key

# Websockets listener
listener 9001
protocol websockets
```

### Managing users

Use mosquitto_passwd to create a password file. Example (runs inside a temporary container):

```bash
# create a password file with a user 'testuser'
docker run --rm -v $(pwd)/config:/mosquitto/config \
  <your-namespace>/dhi-eclipse-mosquitto:<tag> mosquitto_passwd -b /mosquitto/config/passwordfile testuser 's3cret'
```

After creating the passwordfile, restart the broker so it picks up the new file.

## Configuration and volumes

- /mosquitto/config: configuration files (mosquitto.conf, password files, certs). Mount this as read-only when possible.
- /mosquitto/data: persistence for message queues and DB (if enabled) — mount a writable volume for production.
- /mosquitto/log: broker logs — mount if you need persistent logs.

When updating configuration files, you must restart the Mosquitto container for changes to take effect.

## Health checks and monitoring

Mosquitto does not expose a standardized HTTP health endpoint by default. Use one of the following patterns for health
checks:

- OS-level process check via docker healthcheck that verifies mosquitto process is running.
- Publish/subscribe check: run a short script that publishes a message to a test topic and subscribes to verify
  delivery.

Example Dockerfile HEALTHCHECK (add to a custom image if needed):

```
HEALTHCHECK --interval=30s --timeout=5s \
  CMD mosquitto_pub -h 127.0.0.1 -t health/check -m ping || exit 1
```

## Troubleshooting

- Broker logs: check files in /mosquitto/log or container logs via docker logs.
- Permissions: non-dev hardened images run as a non-root user. Ensure mounted volumes and files are accessible to the
  container user (adjust ownership or use appropriate UIDs if needed).
- Ports: confirm listeners in mosquitto.conf; the container maps host ports to container ports, but the broker must be
  configured to listen on those container ports.

## Additional resources

- Official documentation: https://mosquitto.org/documentation/
- Docker upstream image: https://hub.docker.com/_/eclipse-mosquitto/
- Source code: https://github.com/eclipse-mosquitto/mosquitto

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

| Item               | Migration note                                                                                                                                                                                                                                                                                                            |
| :----------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Base image         | Replace your base images in your Dockerfile with a Docker Hardened Image.                                                                                                                                                                                                                                                 |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                                                                                                                                               |
| Non-root user      | By default non-dev images, intended for runtime, run as the nonroot user. Ensure that necessary files and directories are accessible to the nonroot user.                                                                                                                                                                 |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. To ensure that your final image is as minimal as possible, you should use a multi-stage build.                                                                                                                                           |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                                                                                                                                                        |
| Ports              | Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20. To avoid issues, configure your application to listen on port 1025 or higher inside the container. |
| Entry point        | Docker Hardened Images may have different entry points than images such as Docker Official Images. Inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.                                                                                                                               |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use dev images in build stages to run shell commands and then copy any necessary artifacts into the runtime stage.                                                                                                                               |

## Troubleshooting migration

The following are common issues that you may encounter during migration.

### General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use Docker Debug to attach to these containers.

### Permissions

By default image variants intended for runtime, run as the nonroot user. Ensure that necessary files and directories are
accessible to the nonroot user.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10.

### No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
