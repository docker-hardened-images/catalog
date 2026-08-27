## How to use this image

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/selenium-node-chromium:<tag>`
- Mirrored image: `<your-namespace>/dhi-selenium-node-chromium:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

### What's included in this selenium-node-chromium image

This Docker Hardened Selenium Node image runs the Node role of a Selenium Grid and ships Chromium with chromedriver as
its browser. The Node receives WebDriver session requests routed from a Selenium Hub, spawns a chromedriver subprocess
per session, and drives Chromium for the lifetime of that session. It is the canonical browser node for arm64 Grids
(where Google Chrome is not distributed) and a drop-in alternative to `selenium/node-chrome` on amd64.

The image ships:

- The `selenium-server` JAR (the same artifact used by the official Selenium project) built from source with Bazel.
- Chromium and chromedriver from the Debian trixie apt sources (`trixie/main` plus the `trixie-security` channel).
- An entrypoint script at `/usr/local/bin/selenium-node`. The script is a port of upstream `selenium/node-chromium`'s
  `start-selenium-node.sh` that maps upstream's `SE_*` environment variables (node host/port, max sessions, timeouts,
  drain count, TLS, tracing, JVM options) onto `selenium-server node` flags, so an existing `selenium/node-chromium`
  configuration carries over. It also reads `SE_HUB_HOST`/`SE_HUB_PORT` (mapped to `--grid-url`), which upstream
  ignores.

Two functional differences from upstream:

1. **No VNC / Xvfb / fluxbox stack.** The image has no X server, so WebDriver clients must request headless mode (for
   example `--headless=new` in `goog:chromeOptions`); upstream's Xvfb also allows headful sessions. The upstream
   `supervisord` + `x11vnc` + `noVNC` + `fluxbox` debugging stack is intentionally omitted. See `overview.md` for the
   rationale.
1. **No bundled Prometheus metrics exporter.** Matches `dhi/selenium-hub`'s same divergence.

### Run the selenium-node-chromium container

A Node by itself does nothing useful: it must register with a Hub. The simplest deployment runs the Hub and at least one
Node on the same Docker network. See **Hub and Node with Docker Compose** below for a complete example.

To start a Node manually, point it at a running Hub via `SE_EVENT_BUS_*` and `SE_HUB_*`:

```bash
docker run -d \
  --name chromium-node \
  --network selenium-grid \
  -p 5555:5555 \
  -e SE_EVENT_BUS_HOST=selenium-hub \
  -e SE_EVENT_BUS_PUBLISH_PORT=4442 \
  -e SE_EVENT_BUS_SUBSCRIBE_PORT=4443 \
  -e SE_HUB_HOST=selenium-hub \
  -e SE_HUB_PORT=4444 \
  dhi.io/selenium-node-chromium:<tag>
```

The Node is operational as soon as the log contains a line that looks like:

```
Node has been added
```

Confirm registration by querying the Hub's `/status` endpoint and looking for the new Node in `value.nodes`:

```bash
curl -s http://localhost:4444/status | python3 -c "import json,sys; print(len(json.load(sys.stdin)['value']['nodes']))"
```

### Hub and Node with Docker Compose

The following `compose.yml` starts a Hub alongside a single Chromium Node. The Node connects back to the Hub over the
shared Docker network.

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
    image: dhi.io/selenium-node-chromium:<tag>
    depends_on:
      - selenium-hub
    environment:
      SE_EVENT_BUS_HOST: selenium-hub
      SE_EVENT_BUS_PUBLISH_PORT: "4442"
      SE_EVENT_BUS_SUBSCRIBE_PORT: "4443"
      SE_HUB_HOST: selenium-hub
      SE_HUB_PORT: "4444"
      SE_NODE_MAX_SESSIONS: "1"
```

Start both services:

```bash
docker compose up -d
```

Point your WebDriver client at `http://localhost:4444/wd/hub` (or `http://localhost:4444` for W3C-style clients). The
Grid UI at http://localhost:4444/ui shows the registered Node and an available chromium slot.

> **Pin Hub and Node to the same version.** A Selenium Grid does not reliably tolerate a version mismatch between the
> Hub and its Nodes; upstream has shipped node-to-hub registration breakage within the 4.x line. Deploy
> `dhi/selenium-hub` and `dhi/selenium-node-chromium` on the **same** selenium-server version, and prefer an exact tag
> (for example `:4.44.0`) on both rather than the floating `:4`, so a bump to one image cannot silently desync the Grid.

### Scaling: multiple Nodes against a single Hub

To run multiple Nodes on the same host, scale the compose service — each replica gets its own identity on the compose
network, so no per-replica ports are needed. (Nodes started with `docker run` and published host ports instead need a
distinct port and `SE_NODE_HOST` each.)

```bash
docker compose up -d --scale chromium-node=4
```

Each replica registers independently and the Hub round-robins sessions across them up to `SE_NODE_MAX_SESSIONS` slots
per Node.

### Configuration reference

The entrypoint script maps the following environment variables to Node CLI flags. All variables are optional; the
defaults shown are the values baked into the image.

| Variable                           | Default                            | Description                                                                                                                                                                  |
| :--------------------------------- | :--------------------------------- | :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SE_JAVA_OPTS`                     | (none)                             | Additional JVM flags, appended after `SE_JAVA_OPTS_DEFAULT`.                                                                                                                 |
| `JAVA_OPTS`                        | (none)                             | Legacy JVM flags alias. Applied after `SE_JAVA_OPTS`.                                                                                                                        |
| `SE_OPTS`                          | (none)                             | Arbitrary `selenium-server node` flags passed verbatim.                                                                                                                      |
| `SE_HUB_HOST`                      | `selenium-hub`                     | Hostname of the Hub this Node should register with.                                                                                                                          |
| `SE_HUB_PORT`                      | `4444`                             | Hub HTTP port.                                                                                                                                                               |
| `SE_NODE_HOST`                     | (none)                             | `--host` — advertised hostname of this Node, used by the Hub to reach it.                                                                                                    |
| `SE_NODE_PORT`                     | `5555`                             | `--port` — Node listening port.                                                                                                                                              |
| `SE_NODE_GRID_URL`                 | (none)                             | `--grid-url` — explicit URL the Node uses to reach the Hub (overrides `SE_HUB_HOST`/`SE_HUB_PORT`).                                                                          |
| `SE_NODE_MAX_SESSIONS`             | `1`                                | `--max-sessions` — concurrent browser sessions this Node will accept.                                                                                                        |
| `SE_NODE_SESSION_TIMEOUT`          | `300`                              | `--session-timeout` — seconds before an idle session is reaped.                                                                                                              |
| `SE_NODE_REGISTER_PERIOD`          | `120`                              | `--register-period` — seconds the Node keeps retrying initial registration before giving up.                                                                                 |
| `SE_NODE_REGISTER_CYCLE`           | `10`                               | `--register-cycle` — seconds between retries within the register period.                                                                                                     |
| `SE_DRAIN_AFTER_SESSION_COUNT`     | `0`                                | `--drain-after-session-count` — gracefully drain the Node after serving N sessions; `0` disables. `SE_NODE_DRAIN_AFTER_SESSION_COUNT` (DHI extension) overrides it when set. |
| `SE_NODE_DETECT_DRIVERS`           | `true`                             | `--detect-drivers` — autodetect chromedriver/chromium from `$PATH`. Required `true` for the node to register the configured chromium stereotype.                             |
| `SE_NODE_ENABLE_MANAGED_DOWNLOADS` | (none)                             | `--enable-managed-downloads` — let the Hub serve files downloaded inside Chromium sessions.                                                                                  |
| `SE_NODE_ENABLE_CDP`               | (none)                             | `--enable-cdp` — expose the Chromium DevTools Protocol endpoint via the Grid.                                                                                                |
| `SE_NODE_BROWSER_VERSION`          | `stable`                           | Stereotype `browserVersion` value advertised to the Hub.                                                                                                                     |
| `SE_LOG_LEVEL`                     | `INFO`                             | `--log-level` — Java logging level (e.g. `FINE`, `WARNING`).                                                                                                                 |
| `SE_BIND_HOST`                     | `false`                            | `--bind-host` — bind the Node to the value of `SE_NODE_HOST` only.                                                                                                           |
| `SE_REGISTRATION_SECRET`           | (none)                             | `--registration-secret` — shared secret the Hub requires when the Node registers.                                                                                            |
| `SE_EVENT_BUS_HOST`                | (none)                             | Hub hostname for the Event Bus (required; the Node refuses to start without it).                                                                                             |
| `SE_EVENT_BUS_PUBLISH_PORT`        | `4442`                             | Event Bus publish port.                                                                                                                                                      |
| `SE_EVENT_BUS_SUBSCRIBE_PORT`      | `4443`                             | Event Bus subscribe port.                                                                                                                                                    |
| `SE_ENABLE_TLS`                    | `false`                            | When `true`, the Node terminates HTTPS and the Hub URL switches to `https://`.                                                                                               |
| `SE_HTTPS_CERTIFICATE`             | `/opt/selenium/secrets/tls.crt`    | TLS certificate path (mount via volume).                                                                                                                                     |
| `SE_HTTPS_PRIVATE_KEY`             | `/opt/selenium/secrets/tls.key`    | TLS private key path (mount via volume).                                                                                                                                     |
| `SE_JAVA_SSL_TRUST_STORE`          | `/opt/selenium/secrets/server.jks` | Trust store used to validate the Hub's TLS certificate.                                                                                                                      |
| `SE_ENABLE_TRACING`                | `true`                             | OpenTelemetry tracing. Exports only when `SE_OTEL_EXPORTER_ENDPOINT` is also set; the OTLP exporter jars are not bundled and must be supplied via `SE_EXTRA_LIBS`.           |

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

## Migrate to a Docker Hardened Image

If you currently use `selenium/node-chromium`, swap the image reference:

```diff
- image: selenium/node-chromium:latest
+ image: dhi.io/selenium-node-chromium:<tag>
```

The upstream `SE_*` variables listed in the configuration reference above carry over unchanged; variables outside that
set (for example `SE_NODE_STEREOTYPE` or `SE_BROWSER_BINARY_LOCATION`) are not mapped by this entrypoint. The image
additionally reads a few variables upstream ignores (for example `SE_HUB_HOST`/`SE_HUB_PORT`, mapped to `--grid-url`).
The functional differences (no VNC, no Prometheus exporter, no supervisord process stack) are described in `overview.md`
and at the top of this guide.

## Troubleshooting migration

### General debugging

The runtime image contains `bash` but does not include `coreutils`, `curl`, a package manager, or broader debugging
tooling. For more thorough debugging use [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach
to running containers.

### Permissions

By default image variants intended for runtime run as a nonroot user. Ensure that mounted directories (TLS material,
heap-dump targets) are readable by uid 65532.

### Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The Node's
default port `5555` is well above 1024 so this rarely matters.

### Entry point

The runtime image's entrypoint is `/usr/local/bin/selenium-node`. Override it with `--entrypoint` only if you need to
inspect the container manually; for normal operation the entrypoint script is what consumes the `SE_*` environment
contract and starts the JVM in node mode.
