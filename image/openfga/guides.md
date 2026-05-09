## Prerequisite

All examples in this guide use the public image. If you've mirrored the repository for your own use (for example, to
your Docker Hub namespace), update your commands to reference the mirrored image instead of the public one.

For example:

- Public image: `dhi.io/<repository>:<tag>`
- Mirrored image: `<your-namespace>/dhi-<repository>:<tag>`

For the examples, you must first use `docker login dhi.io` to authenticate to the registry to pull the images.

## What's included in this OpenFGA Hardened image

OpenFGA is an open-source authorization engine inspired by Google Zanzibar that lets developers model fine-grained,
relationship-based permissions and resolve them at scale. It exposes both an HTTP and a gRPC API for managing
authorization models, writing relationship tuples, and answering authorization checks.

This Docker Hardened OpenFGA image includes:

- `openfga` (the OpenFGA server binary, set as the image entrypoint)
- `grpc_health_probe` (a standalone CLI for probing gRPC health endpoints, useful for container health checks)

The OpenFGA CLI is a multi-subcommand tool. The most commonly used subcommands are `run` (start the server), `migrate`
(apply database schema migrations), `version` (print version info), and `validate-models` (validate authorization model
files). The image's ENTRYPOINT is just `openfga` with no default subcommand, so you must always pass a subcommand when
starting a container.

The image declares three TCP ports: `8080` (HTTP API server), `8081` (gRPC API server), and `3000` (Playground UI,
disabled by default).

For the following examples, replace `<tag>` with the image variant you want to run. To confirm the correct namespace and
repository name of the mirrored repository, select **View in repository**.

# Start an OpenFGA instance

To start an OpenFGA server, pass the `run` subcommand. By default, the server uses an in-memory datastore — useful for
trying things out, but data is lost when the container stops:

```bash
$ docker run -d -p 8080:8080 -p 8081:8081 dhi.io/openfga:<tag> run
```

This starts OpenFGA with two API servers:

- Port `8080` — HTTP API server
- Port `8081` — gRPC API server

You can verify the server is up via either protocol. The HTTP healthcheck endpoint:

```bash
$ curl http://localhost:8080/healthz
{"status":"SERVING"}
```

Or use the bundled `grpc_health_probe` binary inside the container:

```bash
$ docker exec <container-name> grpc_health_probe -addr=localhost:8081
status: SERVING
```

To check the OpenFGA version:

```bash
$ docker run --rm dhi.io/openfga:<tag> version
```

> **Default config notes.** The server runs with authentication and TLS disabled by default. Both are logged as warnings
> on startup (`authentication is disabled`, `gRPC TLS is disabled, serving connections using insecure plaintext`). For
> any non-development use, configure authentication (`--authn-method`) and TLS (`--http-tls-enabled`,
> `--grpc-tls-enabled`).

# Common OpenFGA use cases

## Use Postgres as the datastore

For persistent storage, configure OpenFGA to use a Postgres database. This is a two-step process: first run the
`migrate` subcommand to apply the schema, then run the server.

**Step 1: Start a Postgres database** (or use an existing one):

```bash
$ docker network create openfga-net
$ docker run -d --name postgres --network openfga-net \
    -e POSTGRES_USER=openfga \
    -e POSTGRES_PASSWORD=secret \
    -e POSTGRES_DB=openfga \
    postgres:16
```

**Step 2: Apply the OpenFGA schema** with the `migrate` subcommand. This is required before the first `run`; without it,
the server starts but has no tables to query:

```bash
$ docker run --rm --network openfga-net \
    -e OPENFGA_DATASTORE_ENGINE=postgres \
    -e OPENFGA_DATASTORE_URI="postgres://openfga:secret@postgres:5432/openfga?sslmode=disable" \
    dhi.io/openfga:<tag> migrate
```

The `migrate` subcommand exits cleanly after applying the schema (`migration done`).

**Step 3: Run the server** against the Postgres datastore:

```bash
$ docker run -d --name openfga --network openfga-net \
    -p 8080:8080 -p 8081:8081 \
    -e OPENFGA_DATASTORE_ENGINE=postgres \
    -e OPENFGA_DATASTORE_URI="postgres://openfga:secret@postgres:5432/openfga?sslmode=disable" \
    dhi.io/openfga:<tag> run
```

OpenFGA also supports a `mysql` datastore engine; the same pattern applies with `OPENFGA_DATASTORE_ENGINE=mysql` and a
corresponding `OPENFGA_DATASTORE_URI`.

## Validate authorization models

Use the `validate-models` subcommand to check authorization model files for syntax errors before applying them to a
running server:

```bash
$ docker run --rm -v $(pwd):/workspace dhi.io/openfga:<tag> \
    validate-models -f /workspace/authorization-model.fga
```

The `validate-models` command exits cleanly on valid models and prints errors on invalid ones.

## Health checks for orchestration

The bundled `grpc_health_probe` binary makes it easy to configure liveness and readiness probes in container
orchestrators. For example, in a Kubernetes pod spec:

```yaml
livenessProbe:
  exec:
    command:
      - /usr/local/bin/grpc_health_probe
      - -addr=localhost:8081
  initialDelaySeconds: 10
readinessProbe:
  exec:
    command:
      - /usr/local/bin/grpc_health_probe
      - -addr=localhost:8081
  initialDelaySeconds: 5
```

The HTTP healthcheck at `http://<host>:8080/healthz` is also available for HTTP-based liveness probes.

## Configuration via environment variables

OpenFGA is configured entirely via flags or environment variables. Every flag has a corresponding `OPENFGA_*`
environment variable. Common ones:

| Environment variable         | Description                                       | Default        |
| ---------------------------- | ------------------------------------------------- | -------------- |
| `OPENFGA_DATASTORE_ENGINE`   | Storage backend (`memory`, `postgres`, `mysql`)   | `memory`       |
| `OPENFGA_DATASTORE_URI`      | Datastore connection string                       | (none)         |
| `OPENFGA_HTTP_ADDR`          | HTTP server bind address                          | `0.0.0.0:8080` |
| `OPENFGA_GRPC_ADDR`          | gRPC server bind address                          | `0.0.0.0:8081` |
| `OPENFGA_PLAYGROUND_ENABLED` | Enable the Playground UI on port 3000             | `false`        |
| `OPENFGA_AUTHN_METHOD`       | Authentication mode (`none`, `preshared`, `oidc`) | `none`         |
| `OPENFGA_LOG_LEVEL`          | Log level (`debug`, `info`, `warn`, `error`)      | `info`         |
| `OPENFGA_METRICS_ADDR`       | Prometheus metrics server address                 | `0.0.0.0:2112` |

For the full list of options, run:

```bash
$ docker run --rm dhi.io/openfga:<tag> run --help
```

For the full upstream documentation including authorization modeling guides, the API reference, and SDK usage, see
https://openfga.dev.

# Non-hardened images vs Docker Hardened Images

## Key differences

| Feature         | Docker Official OpenFGA             | Docker Hardened OpenFGA                             |
| --------------- | ----------------------------------- | --------------------------------------------------- |
| Security        | Standard base with common utilities | Minimal, hardened Debian 13 base                    |
| Shell access    | Full shell available                | No shell in runtime variants                        |
| Package manager | `apk` / `apt` available             | No package manager in runtime variants              |
| User            | Runs as a low-numbered nonroot UID  | Runs as nonroot user (UID 65532)                    |
| Attack surface  | Larger due to additional utilities  | Minimal — binaries only, no other tools             |
| Debugging       | Traditional shell debugging         | Use Docker Debug or Image Mount for troubleshooting |
| Compliance      | None                                | CIS                                                 |
| Attestations    | None                                | SBOM, provenance, VEX metadata                      |

## Why no shell or package manager?

Docker Hardened Images prioritize security through minimalism:

- **Reduced attack surface**: Fewer binaries mean fewer potential vulnerabilities
- **Immutable infrastructure**: Runtime containers shouldn't be modified after deployment
- **Compliance ready**: Meets strict security requirements for regulated environments

The hardened image contains only the `openfga` and `grpc_health_probe` binaries and their required libraries — no shell,
no coreutils, no package manager, no editors. Common debugging methods for applications built with Docker Hardened
Images include:

- [Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to containers
- Docker's Image Mount feature to mount debugging tools

Docker Debug provides a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer
that only exists during the debugging session. For example:

```bash
$ docker debug openfga
```

Or mount debugging tools with the Image Mount feature:

```bash
$ docker run --rm -it --pid container:openfga \
    --mount=type=image,source=dhi.io/busybox:1,destination=/dbg,ro \
    --entrypoint /dbg/bin/sh \
    dhi.io/openfga:<tag>
```

For operational visibility without attaching a debugger, OpenFGA exposes a Prometheus metrics server on port `2112` by
default, which reports request latencies, error rates, and datastore performance.

# Image variants

Docker Hardened Images come in different variants depending on their intended use.

Runtime variants are designed to run your application in production. These images are intended to be used either
directly or as the `FROM` image in the final stage of a multi-stage build. These images typically:

- Run as the nonroot user (UID 65532)
- Do not include a shell or a package manager
- Contain only the minimal set of libraries needed to run the app

Build-time variants include `dev` in the variant name and are intended for use in the first stage of a multi-stage
Dockerfile. These images typically:

- Run as the root user
- Include a shell (`bash` and `/bin/sh`) and a package manager (`apt`)
- Are used to build or compile applications

The OpenFGA image is published in the following variants:

| Variant          | Tag pattern                               | User    | Compliance | Availability |
| ---------------- | ----------------------------------------- | ------- | ---------- | ------------ |
| Runtime          | `<version>`, `<version>-debian13`         | nonroot | CIS        | Public       |
| Build-time (dev) | `<version>-dev`, `<version>-debian13-dev` | root    | CIS        | Public       |

DHI tags use the upstream version number directly with no `v` prefix (for example, `1.15`, not `v1.15.1`). Tags also
include rolling major-version aliases — `1` always points to the latest 1.x release, and `1.15` to the latest 1.15.x
patch.

To view all published tags and get more information about each variant, select the **Tags** tab for this repository.

## Migrate to a Docker Hardened Image

To migrate your application to a Docker Hardened Image, you must update your Dockerfile or runtime configuration. At
minimum, you must update the base image in your existing Dockerfile to a Docker Hardened Image. This and a few other
common changes are listed in the following table of migration notes.

| Item               | Migration note                                                                                                                                                                             |
| :----------------- | :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Base image         | Replace your base image with `dhi.io/openfga:<tag>`. Note that DHI tags use no `v` prefix.                                                                                                 |
| Package management | Non-dev images, intended for runtime, don't contain package managers. Use package managers only in images with a `dev` tag.                                                                |
| Non-root user      | By default, non-dev images, intended for runtime, run as the nonroot user (UID 65532). Ensure that any mounted authorization model files or TLS certificates are readable by UID 65532.    |
| Multi-stage build  | Utilize images with a `dev` tag for build stages and non-dev images for runtime. For binary executables, use a `static` image for runtime.                                                 |
| TLS certificates   | Docker Hardened Images contain standard TLS certificates by default. There is no need to install TLS certificates.                                                                         |
| Ports              | The image exposes ports 8080 (HTTP), 8081 (gRPC), and 3000 (Playground, disabled by default). All are above 1024 and unaffected by the privileged-port restriction for nonroot containers. |
| Entry point        | The entrypoint is `openfga` with no default subcommand. You must always pass a subcommand: `run` (start the server), `migrate` (apply schema), `version`, or `validate-models`.            |
| No shell           | By default, non-dev images, intended for runtime, don't contain a shell. Use `dev` images in build stages to run shell commands and then copy artifacts to the runtime stage.              |

The following steps outline the general migration process.

1. **Find hardened images for your app.**

   A hardened image may have several variants. Inspect the image tags and find the image variant that meets your needs.

1. **Update the base image in your Dockerfile.**

   Update the base image in your application's Dockerfile to the hardened image you found in the previous step.

1. **For multi-stage Dockerfiles, update the runtime image in your Dockerfile.**

   To ensure that your final image is as minimal as possible, you should use a multi-stage build. All stages in your
   Dockerfile should use a hardened image. While intermediary stages will typically use images tagged as `dev`, your
   final runtime stage should use a non-dev image variant.

1. **Install additional packages.**

   Docker Hardened Images contain minimal packages in order to reduce the potential attack surface. Only images tagged
   as `dev` typically have package managers. You should use a multi-stage Dockerfile to install the packages. Install
   the packages in the build stage that uses a `dev` image. Then, if needed, copy any necessary artifacts to the runtime
   stage that uses a non-dev image.

   For Debian-based images, you can use `apt-get` to install packages.

# Troubleshoot migration

The following are common issues that you may encounter during migration.

## General debugging

The hardened images intended for runtime don't contain a shell nor any tools for debugging. The recommended method for
debugging applications built with Docker Hardened Images is to use
[Docker Debug](https://docs.docker.com/reference/cli/docker/debug/) to attach to these containers. Docker Debug provides
a shell, common debugging tools, and lets you install other tools in an ephemeral, writable layer that only exists
during the debugging session.

For OpenFGA specifically, most operational debugging can be done through:

- The HTTP healthcheck at `http://<host>:8080/healthz`
- The bundled `grpc_health_probe` for gRPC liveness checks
- The Prometheus metrics endpoint on port `2112` for request rates, latencies, and datastore performance
- Increasing log verbosity with `OPENFGA_LOG_LEVEL=debug`

## Permissions

By default image variants intended for runtime, run as the nonroot user (UID 65532). Ensure that any mounted files
(authorization models, TLS certificates, configuration files) are readable by UID 65532. The OpenFGA binary itself does
not write to disk — all state is in the configured datastore — so write permissions on mounts are typically not needed.

## Privileged ports

Non-dev hardened images run as a nonroot user by default. As a result, applications in these images can't bind to
privileged ports (below 1024) when running in Kubernetes or in Docker Engine versions older than 20.10. The default
OpenFGA ports (8080, 8081, 3000, 2112) are all above 1024 and are unaffected. If you override `OPENFGA_HTTP_ADDR` or
`OPENFGA_GRPC_ADDR`, use ports above 1024.

## No shell

By default, image variants intended for runtime don't contain a shell. Use `dev` images in build stages to run shell
commands and then copy any necessary artifacts into the runtime stage. In addition, use Docker Debug to debug containers
with no shell.

## Entry point

The hardened image's entrypoint is `openfga`. Unlike some Docker Official Images, the OpenFGA CLI requires an explicit
subcommand:

```bash
$ docker run -d ... dhi.io/openfga:<tag> run        # Start the server
$ docker run --rm dhi.io/openfga:<tag> migrate      # Apply database schema
$ docker run --rm dhi.io/openfga:<tag> version      # Print version
```

Running the image with no subcommand prints the help text and exits cleanly with no error — the container will appear to
start and then immediately stop.

Use `docker inspect` to view the entrypoint and any default arguments for a specific tag.
