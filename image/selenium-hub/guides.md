## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/selenium-hub:<tag>`
- Mirrored image: `<your-namespace>/dhi-selenium-hub:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this selenium-hub image

This Docker Hardened Selenium Hub image runs the Hub role of a Selenium Grid. The Hub is the central coordinator that
receives WebDriver session requests from test clients and routes them to registered browser Nodes. It exposes the Grid
UI and the WebDriver endpoint on port 4444, and the Event Bus on ports 4442 (publish) and 4443 (subscribe) for Node
registration.

The image ships the `selenium-server` JAR (the same artifact used by the official Selenium project) together with an
entrypoint script at `/usr/local/bin/selenium-hub`. That script is a port of upstream `selenium/hub`'s
`start-selenium-grid-hub.sh`: it maps the same `SE_*` environment variables (host/port, timeouts, basic auth, TLS,
tracing, JVM options) onto `selenium-server hub` flags, so an existing `selenium/hub` configuration carries over. The
one functional difference is that the upstream Prometheus metrics-exporter sidecar (port 9615) is **not** bundled — see
[Non-hardened images vs. Docker Hardened Images](#non-hardened-images-vs-docker-hardened-images).

### Run the selenium-hub container

To start a Hub and expose all three ports:

```bash
docker run -d \
  --name selenium-hub \
  -p 4442:4442 \
  -p 4443:4443 \
  -p 4444:4444 \
  dhi.io/selenium-hub:<tag>
```

The Grid UI is available at http://localhost:4444/ui and the WebDriver endpoint at http://localhost:4444/wd/hub once the
Hub is ready.

### Start a standalone Hub waiting for nodes

Start the Hub and verify it is listening before registering any Nodes. The Hub begins accepting Node registrations
immediately; the Grid UI shows zero sessions until at least one Node connects.

```bash
docker run -d \
  --name selenium-hub \
  -p 4442:4442 \
  -p 4443:4443 \
  -p 4444:4444 \
  dhi.io/selenium-hub:<tag>
```

Check Grid status using the built-in status endpoint (no shell required inside the container — query from the host):

```bash
curl -s http://localhost:4444/status | python3 -m json.tool
```

The Hub is operational as soon as `/status` responds with HTTP 200. Note that `"ready"` stays `false` until at least one
Node registers — a Hub with no Nodes is healthy and accepting registrations, it simply has no browser slots to serve
sessions yet. Once a Node connects, `"ready"` flips to `true`.

### Hub and Node with Docker Compose

The following `compose.yml` starts a Hub alongside a Chromium Node. The Node connects back to the Hub over the shared
Docker network using the `SE_EVENT_BUS_*` variables.

> Note: The node image in this example (`selenium/node-chromium`) is the upstream community image — `node-chromium` is
> used rather than `node-chrome` because it ships both `amd64` and `arm64` (Google Chrome has no ARM Linux build).
> Docker Hardened browser-Node images are separate from this Hub image.

```yaml
services:
  selenium-hub:
    image: dhi.io/selenium-hub:<tag>
    container_name: selenium-hub
    ports:
      - "4442:4442"
      - "4443:4443"
      - "4444:4444"

  chromium-node:
    image: selenium/node-chromium:latest
    container_name: chromium-node
    depends_on:
      - selenium-hub
    environment:
      SE_EVENT_BUS_HOST: selenium-hub
      SE_EVENT_BUS_PUBLISH_PORT: "4442"
      SE_EVENT_BUS_SUBSCRIBE_PORT: "4443"
```

Start both services:

```bash
docker compose up -d
```

Point your WebDriver client at `http://localhost:4444/wd/hub` (or `http://localhost:4444` for W3C-style clients). The
Grid UI at http://localhost:4444/ui shows the registered Node and available browser slots.

### Hub with basic auth and tuned timeouts

Use `SE_ROUTER_USERNAME` and `SE_ROUTER_PASSWORD` to enable HTTP basic authentication on the Grid UI and all `/session`
API endpoints. Adjust `SE_SESSION_REQUEST_TIMEOUT` to control how long the Hub queues a session request before rejecting
it.

```bash
docker run -d \
  --name selenium-hub \
  -p 4442:4442 \
  -p 4443:4443 \
  -p 4444:4444 \
  -e SE_ROUTER_USERNAME=admin \
  -e SE_ROUTER_PASSWORD=secret \
  -e SE_SESSION_REQUEST_TIMEOUT=120 \
  -e SE_SESSION_RETRY_INTERVAL=5 \
  dhi.io/selenium-hub:<tag>
```

### Configuration reference

The entrypoint script maps the following environment variables to Hub CLI flags. All variables are optional; the
defaults shown are the values baked into the image.

| Variable                     | Default                     | Description                                                                                                                                                         |
| :--------------------------- | :-------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `SE_JAVA_OPTS`               | (none)                      | Additional JVM flags, appended after `SE_JAVA_OPTS_DEFAULT`.                                                                                                        |
| `JAVA_OPTS`                  | (none)                      | Legacy JVM flags alias. Applied after `SE_JAVA_OPTS`.                                                                                                               |
| `SE_OPTS`                    | (none)                      | Arbitrary `selenium-server hub` flags passed verbatim.                                                                                                              |
| `SE_HUB_HOST`                | (none)                      | `--host` — advertised hostname of this Hub.                                                                                                                         |
| `SE_HUB_PORT`                | `4444`                      | `--port` — Hub listening port.                                                                                                                                      |
| `SE_SUB_PATH`                | (none)                      | `--sub-path` — URL prefix for all Hub endpoints.                                                                                                                    |
| `SE_EXTERNAL_URL`            | (none)                      | `--external-url` — URL Nodes use to reach this Hub.                                                                                                                 |
| `SE_LOG_LEVEL`               | `INFO`                      | `--log-level` — Java logging level (e.g. `FINE`, `WARNING`).                                                                                                        |
| `SE_SESSION_REQUEST_TIMEOUT` | `300`                       | `--session-request-timeout` — seconds before a queued session request is rejected.                                                                                  |
| `SE_SESSION_RETRY_INTERVAL`  | `15`                        | `--session-retry-interval` — seconds between session-dispatch retries.                                                                                              |
| `SE_HEALTHCHECK_INTERVAL`    | `120`                       | `--healthcheck-interval` — seconds between Node health checks.                                                                                                      |
| `SE_RELAX_CHECKS`            | `true`                      | `--relax-checks` — accept session requests with partial capability matches.                                                                                         |
| `SE_BIND_HOST`               | `false`                     | `--bind-host` — bind the Hub to the value of `SE_HUB_HOST` only.                                                                                                    |
| `SE_REJECT_UNSUPPORTED_CAPS` | `false`                     | `--reject-unsupported-caps` — set to `true` to reject requests for unregistered capability sets immediately.                                                        |
| `SE_TCP_TUNNEL`              | `false`                     | `--tcp-tunnel` — set to `true` to enable TCP tunneling between Distributor and Nodes.                                                                               |
| `SE_REGISTRATION_SECRET`     | (none)                      | `--registration-secret` — shared secret Nodes must present when registering.                                                                                        |
| `SE_ROUTER_USERNAME`         | (none)                      | `--username` — enables HTTP basic auth on the Grid UI and session API.                                                                                              |
| `SE_ROUTER_PASSWORD`         | (none)                      | `--password` — password for HTTP basic auth.                                                                                                                        |
| `SE_DISABLE_UI`              | (none)                      | `--disable-ui` — set to `true` to disable the Grid web console.                                                                                                     |
| `SE_ENABLE_TRACING`          | `true`                      | OpenTelemetry tracing. Exports only when `SE_OTEL_EXPORTER_ENDPOINT` is also set; the OTLP exporter jars are not bundled and must be supplied via `SE_EXTRA_LIBS`.  |
| `SE_ENABLE_TLS`              | `false`                     | Set to `true` to serve HTTPS. Mount certs into `/opt/selenium/secrets` and point `SE_HTTPS_CERTIFICATE` / `SE_HTTPS_PRIVATE_KEY` (and the truststore vars) at them. |
| `CONFIG_FILE`                | `/opt/selenium/config.toml` | `--config` — a TOML config mounted at this path is picked up automatically; override the path or skip it if absent.                                                 |

### Advanced configuration

For advanced deployments — including TLS/HTTPS termination, fully-distributed mode (separate Router, Distributor,
SessionQueue, and EventBus components), OpenTelemetry tracing configuration, and Kubernetes or Helm chart deployment —
refer to the official Selenium Grid documentation at https://www.selenium.dev/documentation/grid/.

## Non-hardened images vs. Docker Hardened Images

The upstream `selenium/hub` image differs from this hardened image in the following ways:

| Item                | Upstream `selenium/hub`                                                              | Docker Hardened `dhi.io/selenium-hub`                                                                     |
| :------------------ | :----------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------- |
| Process manager     | Python `supervisord` (PID 1) wraps the JVM and a Prometheus metrics-exporter sidecar | JVM runs directly as PID 1 via `/usr/local/bin/selenium-hub`; no supervisord, no Python                   |
| Metrics sidecar     | Prometheus exporter on port 9615 included                                            | Not included; port 9615 is not exposed                                                                    |
| Runtime user        | `seluser` (uid 1200)                                                                 | `nonroot` (uid 65532)                                                                                     |
| Shell               | Bash plus a full GNU userland                                                        | Minimal `bash` only (required by the entrypoint wrapper); no package manager and no other shell utilities |
| Jar location        | `/opt/selenium/selenium-server.jar`                                                  | `/opt/selenium/selenium-server.jar` (same)                                                                |
| `SE_*` env contract | Honored via supervisord wrapper                                                      | Honored via `/usr/local/bin/selenium-hub` entrypoint script                                               |

The two removed pieces are easy to recover when you need them:

- **Prometheus metrics.** The `:9615` exporter is a standalone sidecar, not part of `selenium-server`. Run a Grid
  metrics exporter as its own container pointed at this Hub's GraphQL endpoint, `http://<hub>:4444/graphql`, which
  exposes full Grid state (the Hub's live status is also available as JSON at `/status`).
- **Process supervision.** The Hub JVM runs as PID 1 and shuts down cleanly on `SIGTERM`. Because there is no
  in-container supervisor to restart a crashed process, rely on your orchestrator's restart policy
  (`docker run --restart=on-failure`, Kubernetes `restartPolicy: Always`) — the container-native equivalent of
  upstream's `supervisord` auto-restart.

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
commands and then copy artifacts into the runtime stage. In addition, use Docker Debug to debug containers with no
shell.

### Entry point

Docker Hardened Images may have different entry points than images such as Docker Official Images. Use `docker inspect`
to inspect entry points for Docker Hardened Images and update your Dockerfile if necessary.
